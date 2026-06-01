// StageServer — Multi-duck WebSocket server (Network.framework + CryptoKit).
//
// Forked in spirit from widget/Sources/RubberDuckWidget/MiniServer.swift, but
// adapted for Boy Band's needs:
//   - Path-parameterized WebSocket routing: /duck/{id} where id ∈ D1..D4
//   - Binary frame *sending* (PCM int16 LE) in addition to text
//   - Per-duck connection registry exposed to callers
//
// Wire contract (must match bambu/relay/duck_proxy.py exactly so the
// Bambu firmware doesn't notice it's talking to Stage):
//   - Binary frame, Stage → duck: raw int16 LE PCM mono @ 16000 Hz
//   - Text frame,   Stage → duck: JSON with a "type" field
//                   ("interruption", "ready", ...)
//   - Binary frame, duck → Stage: mic PCM (Stage drops this — we use the Mac mic)
//   - Text frame,   duck → Stage: status / heartbeat — logged, not acted on
//
// If you change the format here, you've broken the firmware. Don't.

import Foundation
import Network
import CryptoKit

// MARK: - Duck identity

/// Stable identifier for one of the four ducks on stage.
/// Always D1..D4, left-to-right from the audience's POV.
enum DuckID: String, CaseIterable, Sendable {
    case D1, D2, D3, D4

    static func parse(_ s: String) -> DuckID? { DuckID(rawValue: s) }
}

// MARK: - Connection wrapper

/// A live WebSocket connection from one duck.
///
/// Thread-safety: NWConnection's send/receive are safe to call from any
/// thread; we just wrap and forward. Marked @unchecked Sendable because
/// NWConnection isn't Sendable in the SDK but is in practice.
final class DuckConnection: @unchecked Sendable {
    let id: UUID
    let duck: DuckID
    let connection: NWConnection
    let connectedAt: Date

    /// Per-connection send queue — ISOLATES ducks from each other. Without
    /// this, all connections shared one dispatch queue, so backpressure on
    /// one duck's socket stalled sends to the others (head-of-line blocking →
    /// the un-jammed duck starved and garbled). One queue per duck = a jam on
    /// one can't delay another.
    private let sendQueue: DispatchQueue
    /// Outstanding (not-yet-acked) PCM sends. When the network backs up this
    /// climbs; past `maxInFlight` we DROP new chunks instead of piling them up.
    private var inFlight = 0
    /// Cap on outstanding sends. Sized to allow PREBUFFERING the whole track
    /// into the duck's 1 MB buffer (≈1500 × 640 B ≈ 960 KB) — for pre-recorded
    /// playback we WANT to fill the buffer, not drop, so WiFi jitter can't
    /// underrun it. The cap still exists as a backstop: a genuinely dead socket
    /// (completions never firing) stops accumulating past ~960KB.
    /// (For LIVE Mode-2 audio later, a much lower cap to drop-and-stay-realtime
    /// is the right call — different mode, revisit then.)
    private let maxInFlight = 1500
    /// Diagnostics: how many chunks we've dropped this connection.
    private(set) var dropped = 0
    private var droppedBytes = 0
    private var sentFrames = 0
    private var sentBytes = 0
    private var completedFrames = 0
    private var completedBytes = 0
    private var inFlightBytes = 0
    private var maxInFlightBytesSeen = 0
    private var lastCompletionMs = 0.0
    private var maxCompletionMs = 0.0
    private var heartbeatTimer: DispatchSourceTimer?
    private var lastPingNs: UInt64?
    private var lastPongNs: UInt64?
    private var lastPongMs = 0.0
    private var maxPongMs = 0.0
    private var heartbeatOutstanding = false

    // ESP32 WiFi power-save can doze between sparse packets. Keep a tiny
    // control packet moving often enough that the radio stays responsive
    // before and during cues.
    private static let heartbeatIntervalMs = 100

    init(duck: DuckID, connection: NWConnection) {
        self.id = UUID()
        self.duck = duck
        self.connection = connection
        self.connectedAt = Date()
        self.sendQueue = DispatchQueue(label: "duck.send.\(duck.rawValue)")
    }

    /// Send a raw PCM (int16 LE) chunk. Real-time discipline: if the socket is
    /// backed up (inFlight ≥ maxInFlight), DROP this chunk rather than queue it
    /// — late audio is useless; a skip beats progressive garble. ~20ms/chunk.
    func sendPCM(_ pcm: Data) {
        let frame = WSFrame.encodeBinary(pcm)
        let pcmBytes = pcm.count
        sendQueue.async {
            if self.inFlight >= self.maxInFlight {
                self.dropped += 1
                self.droppedBytes += pcmBytes
                return  // drop — don't fight through the backlog
            }
            self.inFlight += 1
            self.inFlightBytes += pcmBytes
            self.sentFrames += 1
            self.sentBytes += pcmBytes
            self.maxInFlightBytesSeen = max(self.maxInFlightBytesSeen, self.inFlightBytes)
            let started = DispatchTime.now().uptimeNanoseconds
            self.connection.send(content: frame, completion: .contentProcessed { _ in
                let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000.0
                self.sendQueue.async {
                    self.inFlight -= 1
                    self.inFlightBytes -= pcmBytes
                    self.completedFrames += 1
                    self.completedBytes += pcmBytes
                    self.lastCompletionMs = elapsedMs
                    self.maxCompletionMs = max(self.maxCompletionMs, elapsedMs)
                }
            })
        }
    }

    func startHeartbeat() {
        sendQueue.async {
            self.heartbeatTimer?.cancel()
            let timer = DispatchSource.makeTimerSource(queue: self.sendQueue)
            timer.schedule(deadline: .now() + .milliseconds(100),
                           repeating: .milliseconds(Self.heartbeatIntervalMs))
            timer.setEventHandler { [weak self] in
                self?.sendPing()
            }
            self.heartbeatTimer = timer
            timer.resume()
        }
    }

    private func sendPing() {
        let now = DispatchTime.now().uptimeNanoseconds
        lastPingNs = now
        heartbeatOutstanding = true
        let payload = withUnsafeBytes(of: now.bigEndian) { Data($0) }
        connection.send(content: WSFrame.encodePing(payload), completion: .idempotent)
    }

    func notePong(payload: Data) {
        sendQueue.async {
            let now = DispatchTime.now().uptimeNanoseconds
            self.lastPongNs = now
            self.heartbeatOutstanding = false
            let pingNs = self.decodePingTimestamp(payload) ?? self.lastPingNs ?? now
            let elapsedMs = Double(now - pingNs) / 1_000_000.0
            self.lastPongMs = elapsedMs
            self.maxPongMs = max(self.maxPongMs, elapsedMs)
        }
    }

    private func decodePingTimestamp(_ payload: Data) -> UInt64? {
        guard payload.count == 8 else { return nil }
        return payload.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
    }

    struct SendStats: Sendable {
        let sentFrames: Int
        let sentBytes: Int
        let completedFrames: Int
        let completedBytes: Int
        let inFlightFrames: Int
        let inFlightBytes: Int
        let maxInFlightBytesSeen: Int
        let droppedFrames: Int
        let droppedBytes: Int
        let lastCompletionMs: Double
        let maxCompletionMs: Double
        let lastPongMs: Double
        let maxPongMs: Double
        let lastPongAgeMs: Double?
        let outstandingPingAgeMs: Double?
    }

    func stats() -> SendStats {
        sendQueue.sync {
            let now = DispatchTime.now().uptimeNanoseconds
            let pongAge = lastPongNs.map { Double(now - $0) / 1_000_000.0 }
            let pingAge = heartbeatOutstanding ? lastPingNs.map {
                Double(now - $0) / 1_000_000.0
            } : nil
            return SendStats(sentFrames: sentFrames,
                             sentBytes: sentBytes,
                             completedFrames: completedFrames,
                             completedBytes: completedBytes,
                             inFlightFrames: inFlight,
                             inFlightBytes: inFlightBytes,
                             maxInFlightBytesSeen: maxInFlightBytesSeen,
                             droppedFrames: dropped,
                             droppedBytes: droppedBytes,
                             lastCompletionMs: lastCompletionMs,
                             maxCompletionMs: maxCompletionMs,
                             lastPongMs: lastPongMs,
                             maxPongMs: maxPongMs,
                             lastPongAgeMs: pongAge,
                             outstandingPingAgeMs: pingAge)
        }
    }

    /// Send a JSON control text frame. E.g. {"type":"interruption"}.
    func sendText(_ text: String) {
        let frame = WSFrame.encodeText(Data(text.utf8))
        connection.send(content: frame, completion: .idempotent)
    }

    /// Send a JSON dict as a control text frame.
    func sendJSON(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else { return }
        sendText(str)
    }

    func close() {
        sendQueue.async {
            self.heartbeatTimer?.cancel()
            self.heartbeatTimer = nil
        }
        connection.cancel()
    }
}

// MARK: - WebSocket frame codec
//
// Same RFC 6455 framing as widget/MiniServer, plus a binary-encode helper.

enum WSFrame {
    static func encodeText(_ payload: Data) -> Data {
        encode(opcode: 0x81, payload: payload)
    }

    static func encodeBinary(_ payload: Data) -> Data {
        encode(opcode: 0x82, payload: payload)
    }

    static func encodePing(_ payload: Data) -> Data {
        encode(opcode: 0x89, payload: payload)
    }

    private static func encode(opcode: UInt8, payload: Data) -> Data {
        var frame = Data()
        frame.append(opcode) // FIN + opcode (0x81=text, 0x82=binary)
        let len = payload.count
        if len < 126 {
            frame.append(UInt8(len))
        } else if len < 65536 {
            frame.append(126)
            frame.append(UInt8((len >> 8) & 0xFF))
            frame.append(UInt8(len & 0xFF))
        } else {
            frame.append(127)
            for i in stride(from: 56, through: 0, by: -8) {
                frame.append(UInt8((len >> i) & 0xFF))
            }
        }
        frame.append(payload)
        return frame
    }

    /// Decode a client→server frame (masked per RFC 6455).
    static func decode(_ data: Data) -> (opcode: UInt8, payload: Data, consumed: Int)? {
        guard data.count >= 2 else { return nil }
        let opcode = data[0] & 0x0F
        let masked = (data[1] & 0x80) != 0
        var payloadLen = Int(data[1] & 0x7F)
        var headerLen = 2

        if payloadLen == 126 {
            guard data.count >= 4 else { return nil }
            payloadLen = Int(data[2]) << 8 | Int(data[3])
            headerLen = 4
        } else if payloadLen == 127 {
            guard data.count >= 10 else { return nil }
            payloadLen = 0
            for i in 0..<8 { payloadLen = (payloadLen << 8) | Int(data[2 + i]) }
            headerLen = 10
        }

        let maskLen = masked ? 4 : 0
        let totalHeader = headerLen + maskLen
        let totalFrame = totalHeader + payloadLen
        guard data.count >= totalFrame else { return nil }

        var payload = Data(data[totalHeader..<totalFrame])
        if masked {
            let mask = [data[headerLen], data[headerLen + 1],
                        data[headerLen + 2], data[headerLen + 3]]
            for i in 0..<payload.count { payload[i] ^= mask[i % 4] }
        }
        return (opcode, payload, totalFrame)
    }
}

// MARK: - Stage server

/// Callbacks for the lifecycle of a single duck's connection.
struct StageCallbacks: Sendable {
    var onConnect:    (@Sendable (DuckConnection) -> Void)?
    var onDisconnect: (@Sendable (DuckConnection) -> Void)?
    /// Inbound text from the duck. Status/heartbeat — typically just log.
    var onText:       (@Sendable (DuckConnection, String) -> Void)?
    /// Inbound binary from the duck (mic PCM). Stage drops this on the floor
    /// in normal operation; callback is provided so a debug build can capture
    /// it if needed.
    var onBinary:     (@Sendable (DuckConnection, Data) -> Void)?
}

final class StageServer: @unchecked Sendable {
    let port: UInt16
    private static let unhealthyInFlightBytes = 64 * 1024
    private static let unhealthyLastAckMs = 1000.0
    private static let unhealthyPongMs = 500.0
    private static let unhealthyMissingPongMs = 1000.0
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "boyband.stage.server")
    private var callbacks: StageCallbacks
    private let lock = NSLock()
    private var ducks: [DuckID: DuckConnection] = [:]
    /// Control-channel handler: HTTP GET/POST /play or /stop invokes this
    /// with "play" / "stop". Lets the operator trigger playback without
    /// restarting Stage (which would drop + churn duck connections).
    var onControl: (@Sendable (String) -> Void)?
    /// MAC → slot map used to route real firmware (which hits /ws/duck
    /// and identifies via X-Duck-Id). nil = production path disabled;
    /// only /duck/{ID} works (test/dev mode).
    private let duckMap: DuckMap?

    init(port: UInt16 = 3334,
         duckMap: DuckMap? = nil,
         callbacks: StageCallbacks = StageCallbacks()) {
        self.port = port
        self.duckMap = duckMap
        self.callbacks = callbacks
    }

    func start() throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        let l = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        l.newConnectionHandler = { [weak self] conn in self?.accept(conn) }
        l.stateUpdateHandler = { state in
            if case .failed(let err) = state {
                fputs("[stage-server] listener failed: \(err)\n", stderr)
            }
        }
        listener = l
        l.start(queue: queue)
    }

    func stop() {
        lock.lock()
        let snapshot = Array(ducks.values)
        ducks.removeAll()
        lock.unlock()
        for d in snapshot { d.close() }
        listener?.cancel()
        listener = nil
    }

    /// Currently-connected duck IDs.
    func connectedDucks() -> [DuckID] {
        lock.lock(); defer { lock.unlock() }
        return ducks.keys.sorted { $0.rawValue < $1.rawValue }
    }

    /// Human-readable connection and send counters for `/status`.
    func statusReport() -> String {
        lock.lock()
        let snapshot = ducks.values.sorted { $0.duck.rawValue < $1.duck.rawValue }
        lock.unlock()

        if snapshot.isEmpty { return "connected: none\n" }

        var lines = ["connected: \(snapshot.map { $0.duck.rawValue }.joined(separator: ","))"]
        for conn in snapshot {
            let s = conn.stats()
            let health = Self.healthIssue(for: s).map { "bad(\($0))" } ?? "ok"
            lines.append(String(format:
                "%@: health=%@ sent=%d/%@ completed=%d/%@ inFlight=%d/%@ maxInFlight=%@ dropped=%d/%@ lastAck=%.1fms maxAck=%.1fms pong=%.1fms maxPong=%.1fms pongAge=%@",
                conn.duck.rawValue,
                health,
                s.sentFrames, Self.formatBytes(s.sentBytes),
                s.completedFrames, Self.formatBytes(s.completedBytes),
                s.inFlightFrames, Self.formatBytes(s.inFlightBytes),
                Self.formatBytes(s.maxInFlightBytesSeen),
                s.droppedFrames, Self.formatBytes(s.droppedBytes),
                s.lastCompletionMs, s.maxCompletionMs,
                s.lastPongMs, s.maxPongMs,
                Self.formatMs(s.lastPongAgeMs)))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Human-readable websocket health. A bad connection should be kicked
    /// before playback; during playback it means that duck is already late.
    func healthReport() -> String {
        lock.lock()
        let snapshot = ducks.values.sorted { $0.duck.rawValue < $1.duck.rawValue }
        lock.unlock()

        if snapshot.isEmpty { return "connected: none\n" }

        var lines = ["connected: \(snapshot.map { $0.duck.rawValue }.joined(separator: ","))"]
        for conn in snapshot {
            let s = conn.stats()
            if let issue = Self.healthIssue(for: s) {
                lines.append("\(conn.duck.rawValue): bad \(issue)")
            } else {
                lines.append("\(conn.duck.rawValue): ok")
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Kick a single duck's current socket. BOYBAND firmware reconnects
    /// automatically after Stage closes the websocket.
    @discardableResult
    func kick(_ duck: DuckID) -> Bool {
        lock.lock()
        let conn = ducks.removeValue(forKey: duck)
        lock.unlock()

        guard let conn else { return false }
        conn.close()
        callbacks.onDisconnect?(conn)
        return true
    }

    /// Kick all currently unhealthy sockets. Used as a `/play` preflight:
    /// if anything is already wedged, fail fast and let ducks reconnect
    /// before starting a show cue.
    @discardableResult
    func kickUnhealthyConnections() -> [DuckID] {
        lock.lock()
        let snapshot = ducks.values
            .filter { Self.healthIssue(for: $0.stats()) != nil }
            .sorted { $0.duck.rawValue < $1.duck.rawValue }
        for conn in snapshot {
            if ducks[conn.duck]?.id == conn.id {
                ducks.removeValue(forKey: conn.duck)
            }
        }
        lock.unlock()

        for conn in snapshot {
            conn.close()
            callbacks.onDisconnect?(conn)
        }
        return snapshot.map(\.duck)
    }

    private static func healthIssue(for s: DuckConnection.SendStats) -> String? {
        if s.inFlightBytes >= unhealthyInFlightBytes {
            return "inFlight=\(formatBytes(s.inFlightBytes))"
        }
        if s.lastCompletionMs >= unhealthyLastAckMs {
            return String(format: "lastAck=%.1fms", s.lastCompletionMs)
        }
        if let age = s.outstandingPingAgeMs, age >= unhealthyMissingPongMs {
            return String(format: "missingPong=%.1fms", age)
        }
        if s.lastPongMs >= unhealthyPongMs {
            return String(format: "pong=%.1fms", s.lastPongMs)
        }
        return nil
    }

    private static func formatMs(_ ms: Double?) -> String {
        guard let ms else { return "none" }
        return String(format: "%.1fms", ms)
    }

    private static func formatBytes(_ n: Int) -> String {
        if n >= 1024 * 1024 {
            return String(format: "%.2fMB", Double(n) / 1_048_576.0)
        }
        if n >= 1024 {
            return String(format: "%.1fKB", Double(n) / 1024.0)
        }
        return "\(n)B"
    }

    /// Snapshot of active connections (for broadcast loops).
    func activeConnections() -> [DuckConnection] {
        lock.lock(); defer { lock.unlock() }
        return Array(ducks.values)
    }

    /// Connection for a specific duck, if currently connected.
    func connection(for duck: DuckID) -> DuckConnection? {
        lock.lock(); defer { lock.unlock() }
        return ducks[duck]
    }

    // MARK: - Accept + handshake

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        readHTTP(connection: connection, buffer: Data())
    }

    private func readHTTP(connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) {
            [weak self] data, _, isComplete, _ in
            guard let self, let data else {
                connection.cancel(); return
            }
            var buf = buffer
            buf.append(data)

            guard let headerEnd = buf.findCRLFCRLF() else {
                if !isComplete { self.readHTTP(connection: connection, buffer: buf) }
                else { connection.cancel() }
                return
            }

            let headerStr = String(data: Data(buf[0..<headerEnd]), encoding: .utf8) ?? ""
            guard let parsed = self.parseHeaders(headerStr) else {
                connection.cancel(); return
            }

            // Control endpoints (plain HTTP GET/POST, no WS upgrade). Let us
            // trigger playback on already-connected ducks WITHOUT restarting
            // Stage (restarting drops + churns the duck connections).
            let pathOnly = (parsed.path.components(separatedBy: "?").first ?? parsed.path)
            if parsed.headers["upgrade"]?.lowercased() != "websocket" {
                switch pathOnly {
                case "/play":
                    let kicked = self.kickUnhealthyConnections()
                    if !kicked.isEmpty {
                        let names = kicked.map(\.rawValue).joined(separator: ",")
                        self.sendError(connection, status: 409,
                                       body: "kicked unhealthy socket(s): \(names)\n" +
                                             "wait for reconnect, then trigger /play again\n")
                        return
                    }
                    self.onControl?("play")
                    self.sendError(connection, status: 200, body: "playing\n")
                    return
                case "/stop":
                    self.onControl?("stop")
                    self.sendError(connection, status: 200, body: "stopped\n")
                    return
                case "/status":
                    self.sendError(connection, status: 200, body: self.statusReport())
                    return
                case "/health":
                    self.sendError(connection, status: 200, body: self.healthReport())
                    return
                default:
                    if pathOnly == "/kick" || pathOnly.hasPrefix("/kick/") {
                        self.handleKickRequest(connection: connection, path: parsed.path)
                        return
                    }
                    self.send404(connection)
                    return
                }
            }
            guard let key = parsed.headers["sec-websocket-key"] else {
                self.send404(connection)
                return
            }

            // Resolve to a slot. Two accepted paths:
            //   /duck/{ID}  → test/dev shortcut, slot from path
            //   /ws/duck    → production (real firmware), slot from X-Duck-Id
            switch self.resolveSlot(path: parsed.path, headers: parsed.headers) {
            case .ok(let duck):
                self.upgradeWebSocket(connection: connection, key: key, duck: duck)
            case .unmappedMAC(let mac):
                fputs("[stage-server] reject MAC=\(mac) — not in duck-map " +
                      "(add it to duck-map.local.json and restart)\n", stderr)
                self.sendError(connection, status: 403,
                               body: "MAC \(mac) not in duck-map\n")
            case .missingMAC:
                fputs("[stage-server] reject /ws/duck — missing X-Duck-Id header\n", stderr)
                self.sendError(connection, status: 400,
                               body: "X-Duck-Id header required on /ws/duck\n")
            case .productionDisabled:
                fputs("[stage-server] reject /ws/duck — server started with --no-duck-map\n", stderr)
                self.sendError(connection, status: 503,
                               body: "/ws/duck disabled (no duck-map loaded)\n")
            case .notFound:
                self.send404(connection)
            }
        }
    }

    private enum SlotResolution {
        case ok(DuckID)
        case unmappedMAC(String)
        case missingMAC
        case productionDisabled
        case notFound
    }

    /// Apply both routing rules. See boyband/docs/duck-id-mapping.md.
    private func resolveSlot(path: String, headers: [String: String]) -> SlotResolution {
        // Strip query string for path matching.
        let p = path.components(separatedBy: "?").first ?? path
        let parts = p.split(separator: "/", omittingEmptySubsequences: true).map(String.init)

        // Test/dev path: /duck/{D1..D4}
        if parts.count == 2, parts[0] == "duck", let duck = DuckID.parse(parts[1]) {
            return .ok(duck)
        }

        // Production path: /ws/duck (what real firmware sends)
        if parts == ["ws", "duck"] {
            guard let map = duckMap else { return .productionDisabled }
            guard let mac = headers["x-duck-id"], !mac.isEmpty else { return .missingMAC }
            if let duck = map.lookup(mac: mac) {
                return .ok(duck)
            }
            return .unmappedMAC(mac.uppercased())
        }

        return .notFound
    }

    private func parseHeaders(_ raw: String) -> (method: String, path: String, headers: [String: String])? {
        let lines = raw.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ", maxSplits: 2)
        guard parts.count >= 2 else { return nil }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[line.startIndex..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }
        return (String(parts[0]), String(parts[1]), headers)
    }

    private func handleKickRequest(connection: NWConnection, path: String) {
        if let duck = duckIDFromKickPath(path) {
            let kicked = kick(duck)
            let result = kicked ? "kicked \(duck.rawValue)\n" : "\(duck.rawValue) not connected\n"
            sendError(connection, status: kicked ? 200 : 404, body: result)
            return
        }

        let kicked = kickUnhealthyConnections()
        if kicked.isEmpty {
            sendError(connection, status: 200, body: "no unhealthy sockets\n")
        } else {
            let names = kicked.map(\.rawValue).joined(separator: ",")
            sendError(connection, status: 200, body: "kicked unhealthy socket(s): \(names)\n")
        }
    }

    private func duckIDFromKickPath(_ rawPath: String) -> DuckID? {
        let pieces = rawPath.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let path = String(pieces.first ?? "")
        let parts = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        if parts.count == 2, parts[0] == "kick" {
            return DuckID.parse(parts[1])
        }
        guard pieces.count == 2 else { return nil }
        for item in pieces[1].split(separator: "&") {
            let kv = item.split(separator: "=", maxSplits: 1).map(String.init)
            if kv.count == 2, kv[0] == "duck" {
                return DuckID.parse(kv[1])
            }
        }
        return nil
    }

    private func send404(_ connection: NWConnection) {
        sendError(connection, status: 404,
                  body: "Stage accepts WebSocket upgrades on /ws/duck (with " +
                        "X-Duck-Id header) or /duck/{D1..D4} (test path).\n")
    }

    private func sendError(_ connection: NWConnection, status: Int, body: String) {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 403: statusText = "Forbidden"
        case 409: statusText = "Conflict"
        case 404: statusText = "Not Found"
        case 503: statusText = "Service Unavailable"
        default:  statusText = "Error"
        }
        let resp = "HTTP/1.1 \(status) \(statusText)\r\n" +
                   "Content-Length: \(body.utf8.count)\r\n" +
                   "Connection: close\r\n\r\n\(body)"
        connection.send(content: Data(resp.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func upgradeWebSocket(connection: NWConnection, key: String, duck: DuckID) {
        let accept = wsAcceptKey(key)
        let handshake = "HTTP/1.1 101 Switching Protocols\r\n" +
            "Upgrade: websocket\r\n" +
            "Connection: Upgrade\r\n" +
            "Sec-WebSocket-Accept: \(accept)\r\n\r\n"

        connection.send(content: Data(handshake.utf8), completion: .contentProcessed { [weak self] _ in
            guard let self else { return }
            let duckConn = DuckConnection(duck: duck, connection: connection)

            // Replace any existing connection for this duck — a reconnect
            // means the firmware has dropped the old one.
            self.lock.lock()
            let previous = self.ducks[duck]
            self.ducks[duck] = duckConn
            self.lock.unlock()
            if let previous {
                self.callbacks.onDisconnect?(previous)
                previous.close()
            }

            self.callbacks.onConnect?(duckConn)
            duckConn.startHeartbeat()
            self.readWSFrames(duck: duckConn, buffer: Data())
        })
    }

    private func readWSFrames(duck: DuckConnection, buffer: Data) {
        duck.connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) {
            [weak self] data, _, isComplete, error in
            guard let self else { return }
            guard error == nil, let data else {
                self.handleDisconnect(duck)
                return
            }

            var buf = buffer
            buf.append(data)

            while let frame = WSFrame.decode(buf) {
                buf = Data(buf.dropFirst(frame.consumed))

                switch frame.opcode {
                case 0x1: // Text
                    if let s = String(data: frame.payload, encoding: .utf8) {
                        self.callbacks.onText?(duck, s)
                    }
                case 0x2: // Binary (duck mic) — typically dropped
                    self.callbacks.onBinary?(duck, frame.payload)
                case 0x8: // Close
                    duck.connection.send(content: Data([0x88, 0x00]),
                                         completion: .contentProcessed { _ in
                        duck.connection.cancel()
                    })
                    self.handleDisconnect(duck)
                    return
                case 0x9: // Ping → Pong (echo payload)
                    var pong = Data([0x8A])
                    let p = frame.payload
                    if p.count < 126 { pong.append(UInt8(p.count)) }
                    pong.append(p)
                    duck.connection.send(content: pong, completion: .idempotent)
                case 0xA: // Pong from Stage heartbeat
                    duck.notePong(payload: frame.payload)
                default:
                    break
                }
            }

            if !isComplete {
                self.readWSFrames(duck: duck, buffer: buf)
            } else {
                self.handleDisconnect(duck)
            }
        }
    }

    private func handleDisconnect(_ duck: DuckConnection) {
        var didRemove = false
        lock.lock()
        // Only remove if this is still the registered connection for this
        // duck — a stale callback shouldn't wipe out a fresh reconnect.
        if ducks[duck.duck]?.id == duck.id {
            ducks.removeValue(forKey: duck.duck)
            didRemove = true
        }
        lock.unlock()
        if didRemove { callbacks.onDisconnect?(duck) }
    }

    /// Compute Sec-WebSocket-Accept per RFC 6455.
    private func wsAcceptKey(_ clientKey: String) -> String {
        let magic = clientKey + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        let hash = Insecure.SHA1.hash(data: Data(magic.utf8))
        return Data(hash).base64EncodedString()
    }
}

// MARK: - Data helpers

private extension Data {
    func findCRLFCRLF() -> Int? {
        guard count >= 4 else { return nil }
        for i in 0..<(count - 3) {
            if self[i] == 0x0D && self[i+1] == 0x0A &&
               self[i+2] == 0x0D && self[i+3] == 0x0A { return i }
        }
        return nil
    }
}
