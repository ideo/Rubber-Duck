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
    /// Cap on outstanding sends. For prerecorded playback, `contentProcessed`
    /// can lag even while the duck is still receiving and playing cleanly, so
    /// keep enough headroom to avoid false late-frame drops during healthy
    /// streaming. The cap still prevents an unbounded queue on a dead socket.
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
    private var lastCompletionNs: UInt64?
    private var lastPCMNs: UInt64?
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
            self.lastPCMNs = DispatchTime.now().uptimeNanoseconds
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
                    self.lastCompletionNs = DispatchTime.now().uptimeNanoseconds
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
        if inFlightBytes > 0 {
            return
        }
        if let lastPCMNs, Double(now - lastPCMNs) / 1_000_000.0 < 500.0 {
            return
        }
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
        let lastCompletionAgeMs: Double?
        let maxCompletionMs: Double
        let lastPongMs: Double
        let maxPongMs: Double
        let lastPongAgeMs: Double?
        let outstandingPingAgeMs: Double?
    }

    func stats() -> SendStats {
        sendQueue.sync {
            let now = DispatchTime.now().uptimeNanoseconds
            let completionAge = lastCompletionNs.map { Double(now - $0) / 1_000_000.0 }
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
                             lastCompletionAgeMs: completionAge,
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
    var onControl: (@Sendable (String) -> String)?
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
                "%@: health=%@ sent=%d/%@ completed=%d/%@ inFlight=%d/%@ maxInFlight=%@ dropped=%d/%@ lastAck=%.1fms ackAge=%@ maxAck=%.1fms pong=%.1fms maxPong=%.1fms pongAge=%@",
                conn.duck.rawValue,
                health,
                s.sentFrames, Self.formatBytes(s.sentBytes),
                s.completedFrames, Self.formatBytes(s.completedBytes),
                s.inFlightFrames, Self.formatBytes(s.inFlightBytes),
                Self.formatBytes(s.maxInFlightBytesSeen),
                s.droppedFrames, Self.formatBytes(s.droppedBytes),
                s.lastCompletionMs, Self.formatMs(s.lastCompletionAgeMs), s.maxCompletionMs,
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

    /// Kick only sockets that are currently wedged enough that they are
    /// unlikely to recover by waiting. This is intentionally stricter than
    /// `healthIssue`: the visualizer can warn early, but auto-recovery should
    /// avoid kicking a duck for a harmless one-off slow ACK.
    @discardableResult
    func kickWedgedConnections() -> [DuckID] {
        lock.lock()
        let snapshot = ducks.values
            .filter { Self.recoveryIssue(for: $0.stats()) != nil }
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
        let audioFlowing = isAudioFlowing(s)
        if s.inFlightBytes >= unhealthyInFlightBytes && !audioFlowing {
            return "inFlight=\(formatBytes(s.inFlightBytes))"
        }
        if s.lastCompletionMs >= unhealthyLastAckMs && !audioFlowing {
            return String(format: "lastAck=%.1fms", s.lastCompletionMs)
        }
        if let age = s.outstandingPingAgeMs, age >= unhealthyMissingPongMs && !audioFlowing {
            return String(format: "missingPong=%.1fms", age)
        }
        if s.inFlightBytes > 0 && s.lastPongMs >= unhealthyPongMs && !audioFlowing {
            return String(format: "pong=%.1fms", s.lastPongMs)
        }
        return nil
    }

    private static func recoveryIssue(for s: DuckConnection.SendStats) -> String? {
        let audioFlowing = isAudioFlowing(s)
        if s.inFlightBytes >= 384 * 1024 {
            return "wedgedInFlight=\(formatBytes(s.inFlightBytes))"
        }
        if !audioFlowing && s.inFlightBytes >= 96 * 1024 && s.lastCompletionMs >= 2_500.0 {
            return String(format: "wedgedAck=%.1fms", s.lastCompletionMs)
        }
        if !audioFlowing,
           s.inFlightBytes >= 32 * 1024,
           let age = s.outstandingPingAgeMs,
           age >= 2_500.0 {
            return String(format: "wedgedMissingPong=%.1fms", age)
        }
        return nil
    }

    private static func isAudioFlowing(_ s: DuckConnection.SendStats) -> Bool {
        guard s.sentBytes > 0, s.inFlightBytes > 0, let age = s.lastCompletionAgeMs else {
            return false
        }
        return age < 1_200.0
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

    static func formatBytesForLog(_ n: Int) -> String {
        formatBytes(n)
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
                    let body = self.onControl?("play") ?? "playing\n"
                    self.sendError(connection, status: 200, body: body)
                    return
                case "/stop":
                    let body = self.onControl?("stop") ?? "stopped\n"
                    self.sendError(connection, status: 200, body: body)
                    return
                case "/recover":
                    let kicked = self.kickWedgedConnections()
                    let body = kicked.isEmpty
                        ? "no wedged sockets\n"
                        : "kicked wedged socket(s): \(kicked.map(\.rawValue).joined(separator: ","))\n"
                    self.sendError(connection, status: 200, body: body)
                    return
                case "/next":
                    let body = self.onControl?("next") ?? "next\n"
                    self.sendError(connection, status: 200, body: body)
                    return
                case "/prev":
                    let body = self.onControl?("prev") ?? "prev\n"
                    self.sendError(connection, status: 200, body: body)
                    return
                case "/jump":
                    let index = Self.queryValue("index", in: parsed.path) ?? ""
                    let body = self.onControl?("jump:\(index)") ?? "jump unavailable\n"
                    self.sendError(connection, status: 200, body: body)
                    return
                case "/gain", "/gains":
                    let duck = Self.queryValue("duck", in: parsed.path) ?? ""
                    let value = Self.queryValue("value", in: parsed.path) ?? ""
                    let global = Self.queryValue("global", in: parsed.path) ?? ""
                    let target = global.isEmpty ? duck : "GLOBAL"
                    let setting = global.isEmpty ? value : global
                    let command = target.isEmpty && setting.isEmpty
                        ? "gain"
                        : "gain:\(target)=\(setting)"
                    let body = self.onControl?(command) ?? "{}\n"
                    self.sendResponse(connection, status: 200,
                                      contentType: "application/json",
                                      body: body)
                    return
                case "/cue":
                    let body = self.onControl?("cue") ?? "cue unavailable\n"
                    self.sendError(connection, status: 200, body: body)
                    return
                case "/state":
                    let body = self.onControl?("state") ??
                        "{\"cue\":null,\"status\":\"\(Self.jsonEscape(self.statusReport()))\",\"health\":\"\(Self.jsonEscape(self.healthReport()))\"}\n"
                    self.sendResponse(connection, status: 200,
                                      contentType: "application/json",
                                      body: body)
                    return
                case "/visualizer", "/":
                    self.sendResponse(connection, status: 200,
                                      contentType: "text/html; charset=utf-8",
                                      body: Self.visualizerHTML)
                    return
                case "/subtitles", "/subtitle":
                    self.sendResponse(connection, status: 200,
                                      contentType: "text/html; charset=utf-8",
                                      body: Self.subtitlesHTML)
                    return
                case "/qa":
                    self.sendResponse(connection, status: 200,
                                      contentType: "text/html; charset=utf-8",
                                      body: Self.qaHTML)
                    return
                case "/show":
                    self.sendResponse(connection, status: 200,
                                      contentType: "text/html; charset=utf-8",
                                      body: Self.showHTML)
                    return
                case "/qa.js":
                    self.sendResponse(connection, status: 200,
                                      contentType: "application/javascript; charset=utf-8",
                                      body: Self.qaJS)
                    return
                case "/handoff-video.mp4":
                    self.sendFileResponse(connection,
                                          contentType: "video/mp4",
                                          path: Self.handoffVideoPath)
                    return
                case "/qa/ask":
                    let question = Self.queryValue("question", in: parsed.path) ?? ""
                    let body = self.onControl?("qa:\(question)") ?? "Q&A unavailable\n"
                    if Self.queryValue("format", in: parsed.path) == "frame" {
                        self.sendResponse(connection, status: 200,
                                          contentType: "text/html; charset=utf-8",
                                          body: Self.qaFrameHTML(body))
                    } else {
                        self.sendError(connection, status: 200, body: body)
                    }
                    return
                case "/status":
                    let body = self.onControl?("status") ?? self.statusReport()
                    self.sendError(connection, status: 200, body: body)
                    return
                case "/health":
                    let body = self.onControl?("health") ?? self.healthReport()
                    self.sendError(connection, status: 200, body: body)
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

    private static func queryValue(_ name: String, in rawPath: String) -> String? {
        let pieces = rawPath.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        guard pieces.count == 2 else { return nil }
        for item in pieces[1].split(separator: "&") {
            let kv = item.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard kv.first == Substring(name) else { continue }
            return kv.count == 2 ? String(kv[1]) : ""
        }
        return nil
    }

    private func send404(_ connection: NWConnection) {
        sendError(connection, status: 404,
                  body: "Stage accepts WebSocket upgrades on /ws/duck (with " +
                        "X-Duck-Id header) or /duck/{D1..D4} (test path).\n")
    }

    private func sendError(_ connection: NWConnection, status: Int, body: String) {
        sendResponse(connection, status: status, contentType: "text/plain; charset=utf-8", body: body)
    }

    private func sendResponse(_ connection: NWConnection, status: Int,
                              contentType: String, body: String) {
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
                   "Content-Type: \(contentType)\r\n" +
                   "Content-Length: \(body.utf8.count)\r\n" +
                   "Connection: close\r\n\r\n\(body)"
        connection.send(content: Data(resp.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func sendDataResponse(_ connection: NWConnection, status: Int,
                                  contentType: String, data: Data) {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 404: statusText = "Not Found"
        default:  statusText = "Error"
        }
        let header = "HTTP/1.1 \(status) \(statusText)\r\n" +
                     "Content-Type: \(contentType)\r\n" +
                     "Content-Length: \(data.count)\r\n" +
                     "Connection: close\r\n\r\n"
        var response = Data(header.utf8)
        response.append(data)
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func sendFileResponse(_ connection: NWConnection,
                                  contentType: String,
                                  path: String) {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            sendDataResponse(connection, status: 200, contentType: contentType, data: data)
        } catch {
            sendError(connection, status: 404, body: "file not found\n")
        }
    }

    private static func jsonEscape(_ s: String) -> String {
        var out = ""
        for ch in s {
            switch ch {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default: out.append(ch)
            }
        }
        return out
    }

    private static func htmlEscape(_ s: String) -> String {
        var out = ""
        for ch in s {
            switch ch {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "'": out += "&#39;"
            default: out.append(ch)
            }
        }
        return out
    }

    private static let visualizerHTML = #"""
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Boy Band Stage</title>
  <style>
    :root {
      color-scheme: dark;
      --bg: #101316;
      --panel: #1a2024;
      --panel-2: #20272d;
      --text: #eef3f1;
      --muted: #a8b4b0;
      --line: #344047;
      --ok: #52d273;
      --warn: #ffcc66;
      --bad: #ff6b66;
      --accent: #65c7d3;
      --accent-2: #e7a84e;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      background: var(--bg);
      color: var(--text);
      font: 14px/1.45 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }
    main {
      max-width: 1180px;
      margin: 0 auto;
      padding: 20px;
      display: grid;
      gap: 16px;
    }
    header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
      min-height: 52px;
      border-bottom: 1px solid var(--line);
      padding-bottom: 14px;
    }
    h1 {
      margin: 0;
      font-size: 22px;
      font-weight: 700;
      letter-spacing: 0;
    }
    .status-pill {
      min-width: 130px;
      text-align: center;
      border: 1px solid var(--line);
      border-radius: 6px;
      padding: 7px 10px;
      color: var(--muted);
      background: var(--panel);
      white-space: nowrap;
    }
    .status-pill.ok { color: var(--ok); border-color: color-mix(in srgb, var(--ok), var(--line) 55%); }
    .status-pill.bad { color: var(--bad); border-color: color-mix(in srgb, var(--bad), var(--line) 55%); }
    section {
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 14px;
    }
    .cue-grid {
      display: grid;
      grid-template-columns: minmax(0, 1.4fr) minmax(260px, .8fr);
      gap: 14px;
      align-items: stretch;
    }
    .cue-title {
      display: flex;
      justify-content: space-between;
      gap: 12px;
      align-items: baseline;
      margin-bottom: 12px;
    }
    .cue-title h2 {
      margin: 0;
      font-size: 18px;
      letter-spacing: 0;
    }
    .cue-meta {
      color: var(--muted);
      white-space: nowrap;
    }
    .progress-shell {
      height: 22px;
      border: 1px solid var(--line);
      border-radius: 6px;
      background: #0d1012;
      overflow: hidden;
      position: relative;
    }
    .progress-fill {
      height: 100%;
      width: 0%;
      background: linear-gradient(90deg, var(--accent), var(--accent-2));
      transition: width .25s ease;
    }
    .progress-label {
      position: absolute;
      inset: 0;
      display: grid;
      place-items: center;
      font-size: 12px;
      color: var(--text);
      text-shadow: 0 1px 2px #000;
    }
    .controls {
      display: grid;
      grid-template-columns: repeat(5, minmax(0, 1fr));
      gap: 8px;
      align-content: start;
    }
    button {
      min-height: 42px;
      border: 1px solid var(--line);
      border-radius: 6px;
      background: var(--panel-2);
      color: var(--text);
      font: inherit;
      cursor: pointer;
    }
    button:hover { border-color: var(--accent); }
    button.primary {
      color: #081113;
      background: var(--accent);
      border-color: var(--accent);
      font-weight: 700;
    }
    select {
      min-height: 42px;
      width: 100%;
      border: 1px solid var(--line);
      border-radius: 6px;
      background: var(--panel-2);
      color: var(--text);
      font: inherit;
      padding: 0 10px;
    }
    select:hover { border-color: var(--accent); }
    .jump-control {
      grid-column: 1 / -1;
      display: grid;
      grid-template-columns: minmax(0, 1fr) auto;
      gap: 8px;
    }
    .jump-control button {
      min-width: 74px;
    }
    .ducks {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
      gap: 14px;
    }
    .gain-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
      gap: 12px;
    }
    .gain-global {
      grid-template-columns: minmax(130px, auto) minmax(180px, 1fr) 74px;
      border-bottom: 1px solid var(--line);
      padding-bottom: 12px;
      margin-bottom: 2px;
    }
    .gain-row {
      display: grid;
      grid-template-columns: minmax(86px, auto) minmax(120px, 1fr) 74px 74px;
      align-items: center;
      gap: 10px;
      min-height: 42px;
    }
    .gain-row label {
      color: var(--muted);
      white-space: nowrap;
    }
    .gain-row input[type="range"] {
      width: 100%;
      accent-color: var(--accent);
    }
    .gain-row input[type="number"], .gain-effective {
      width: 74px;
      min-height: 34px;
      border: 1px solid var(--line);
      border-radius: 6px;
      background: #12171a;
      color: var(--text);
      font: inherit;
      padding: 0 8px;
      font-variant-numeric: tabular-nums;
    }
    .gain-effective {
      display: grid;
      place-items: center;
      color: var(--muted);
    }
    .duck-head {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 10px;
      margin-bottom: 10px;
    }
    .duck-head h3 {
      margin: 0;
      font-size: 16px;
      letter-spacing: 0;
    }
    .health {
      border-radius: 6px;
      padding: 4px 8px;
      background: #0d1012;
      color: var(--muted);
      min-width: 56px;
      text-align: center;
    }
    .health.ok { color: var(--ok); }
    .health.bad { color: var(--bad); }
    dl {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 8px;
      margin: 0;
    }
    .metric {
      min-height: 58px;
      border: 1px solid var(--line);
      border-radius: 6px;
      padding: 8px;
      background: #12171a;
    }
    dt {
      margin: 0;
      color: var(--muted);
      font-size: 12px;
    }
    dd {
      margin: 3px 0 0;
      font-size: 16px;
      font-variant-numeric: tabular-nums;
      overflow-wrap: anywhere;
    }
    .log {
      min-height: 120px;
      max-height: 170px;
      overflow: auto;
      white-space: pre-wrap;
      color: var(--muted);
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      font-size: 12px;
      margin: 0;
    }
    @media (max-width: 760px) {
      main { padding: 12px; }
      header, .cue-title { align-items: flex-start; flex-direction: column; }
      .cue-grid, .ducks { grid-template-columns: 1fr; }
      .controls { grid-template-columns: repeat(2, minmax(0, 1fr)); }
      dl { grid-template-columns: repeat(2, minmax(0, 1fr)); }
    }
  </style>
</head>
<body>
  <main>
    <header>
      <h1>Boy Band Stage</h1>
      <div id="overall" class="status-pill">connecting</div>
    </header>

    <section class="cue-grid">
      <div>
        <div class="cue-title">
          <h2 id="cueName">Cue</h2>
          <div id="cueMeta" class="cue-meta">--</div>
        </div>
        <div class="progress-shell">
          <div id="progressFill" class="progress-fill"></div>
          <div id="progressLabel" class="progress-label">0%</div>
        </div>
      </div>
      <div class="controls">
        <button onclick="control('prev')">Prev</button>
        <button class="primary" onclick="control('play')">Play</button>
        <button onclick="control('stop')">Stop</button>
        <button onclick="control('next')">Next</button>
        <button onclick="control('recover')">Recover</button>
        <div class="jump-control">
          <select id="lineSelect" aria-label="Jump to line" onchange="jumpToSelected()">
            <option value="">Jump to line...</option>
          </select>
          <button onclick="jumpToSelected()">Jump</button>
        </div>
      </div>
    </section>

    <section class="ducks">
      <div>
        <div class="duck-head">
          <h3>D1 Classic</h3>
          <div id="D1Health" class="health">--</div>
        </div>
        <dl id="D1Metrics"></dl>
      </div>
      <div>
        <div class="duck-head">
          <h3>D2 Mallard</h3>
          <div id="D2Health" class="health">--</div>
        </div>
        <dl id="D2Metrics"></dl>
      </div>
      <div>
        <div class="duck-head">
          <h3>D3 Pintail</h3>
          <div id="D3Health" class="health">--</div>
        </div>
        <dl id="D3Metrics"></dl>
      </div>
      <div>
        <div class="duck-head">
          <h3>D4 Pekin</h3>
          <div id="D4Health" class="health">--</div>
        </div>
        <dl id="D4Metrics"></dl>
      </div>
    </section>

    <section class="gain-grid" aria-label="Duck gains">
      <div class="gain-row gain-global">
        <label for="GlobalGainRange">Global volume</label>
        <input id="GlobalGainRange" type="range" min="0" max="4" step="0.01" oninput="globalGainInput(this)">
        <input id="GlobalGainNumber" type="number" min="0" max="8" step="0.01" oninput="globalGainInput(this)">
      </div>
      <div class="gain-row">
        <label for="D1GainRange">D1 Classic</label>
        <input id="D1GainRange" type="range" min="0" max="8" step="0.01" oninput="gainInput('D1', this)">
        <input id="D1GainNumber" type="number" min="0" max="8" step="0.01" oninput="gainInput('D1', this)">
        <output id="D1GainEffective" class="gain-effective">--</output>
      </div>
      <div class="gain-row">
        <label for="D2GainRange">D2 Mallard</label>
        <input id="D2GainRange" type="range" min="0" max="8" step="0.01" oninput="gainInput('D2', this)">
        <input id="D2GainNumber" type="number" min="0" max="8" step="0.01" oninput="gainInput('D2', this)">
        <output id="D2GainEffective" class="gain-effective">--</output>
      </div>
      <div class="gain-row">
        <label for="D3GainRange">D3 Pintail</label>
        <input id="D3GainRange" type="range" min="0" max="8" step="0.01" oninput="gainInput('D3', this)">
        <input id="D3GainNumber" type="number" min="0" max="8" step="0.01" oninput="gainInput('D3', this)">
        <output id="D3GainEffective" class="gain-effective">--</output>
      </div>
      <div class="gain-row">
        <label for="D4GainRange">D4 Pekin</label>
        <input id="D4GainRange" type="range" min="0" max="8" step="0.01" oninput="gainInput('D4', this)">
        <input id="D4GainNumber" type="number" min="0" max="8" step="0.01" oninput="gainInput('D4', this)">
        <output id="D4GainEffective" class="gain-effective">--</output>
      </div>
    </section>

    <section>
      <pre id="eventLog" class="log"></pre>
    </section>
  </main>

  <script>
    let lastCue = "";
    let lastTurnListKey = "";
    let metricBaselines = {};
    let gainTimers = {};
    const duckSlots = ["D1", "D2", "D3", "D4"];

    function parseBytes(s) {
      if (!s) return 0;
      const m = String(s).match(/^([0-9.]+)(B|KB|MB)$/);
      if (!m) return Number(s) || 0;
      const v = Number(m[1]);
      return m[2] === "MB" ? v * 1048576 : m[2] === "KB" ? v * 1024 : v;
    }

    function formatBytes(n) {
      n = Math.max(0, n || 0);
      if (n >= 1048576) return (n / 1048576).toFixed(2) + "MB";
      if (n >= 1024) return (n / 1024).toFixed(1) + "KB";
      return Math.round(n) + "B";
    }

    function parseCounter(value) {
      const [frames, bytes] = String(value || "0/0B").split("/");
      return { frames: Number(frames) || 0, bytes: parseBytes(bytes || "0B") };
    }

    function formatCounter(frames, bytes) {
      return `${Math.max(0, frames)}/${formatBytes(bytes)}`;
    }

    function parseStatus(text) {
      const ducks = {};
      for (const line of text.trim().split(/\n+/)) {
        const head = line.match(/^(D[1-4]):\s+health=([^\s]+)/);
        if (!head) continue;
        const duck = head[1];
        ducks[duck] = { health: head[2] };
        for (const part of line.split(/\s+/).slice(2)) {
          const kv = part.split("=");
          if (kv.length === 2) ducks[duck][kv[0]] = kv[1];
        }
      }
      return ducks;
    }

    function captureBaselines(status) {
      metricBaselines = {};
      for (const id of duckSlots) {
        const data = status[id] || {};
        metricBaselines[id] = {
          completed: parseCounter(data.completed),
          sent: parseCounter(data.sent),
          dropped: parseCounter(data.dropped)
        };
      }
    }

    function deltaCounter(data, key, id) {
      const current = parseCounter(data[key]);
      const base = metricBaselines[id]?.[key] || { frames: 0, bytes: 0 };
      return formatCounter(current.frames - base.frames, current.bytes - base.bytes);
    }

    function metricHTML(id, data) {
      const completed = deltaCounter(data, "completed", id);
      const sent = deltaCounter(data, "sent", id);
      const inFlight = data.inFlight || "0/0B";
      const dropped = deltaCounter(data, "dropped", id);
      const pong = data.pong || "--";
      const maxPong = data.maxPong || "--";
      return `
        <div class="metric"><dt>Completed</dt><dd>${completed}</dd></div>
        <div class="metric"><dt>Sent</dt><dd>${sent}</dd></div>
        <div class="metric"><dt>In Flight</dt><dd>${inFlight}</dd></div>
        <div class="metric"><dt>Dropped</dt><dd>${dropped}</dd></div>
        <div class="metric"><dt>Pong</dt><dd>${pong}</dd></div>
        <div class="metric"><dt>Max Pong</dt><dd>${maxPong}</dd></div>`;
    }

    function setHealth(id, value) {
      const el = document.getElementById(id + "Health");
      el.textContent = value || "--";
      el.className = "health " + (value && value.startsWith("ok") ? "ok" : value ? "bad" : "");
    }

    function logLine(s) {
      const el = document.getElementById("eventLog");
      const now = new Date().toLocaleTimeString();
      el.textContent = `[${now}] ${s}\n` + el.textContent;
    }

    function turnOptionLabel(turn) {
      const line = Number.isFinite(turn.line) ? turn.line : (turn.index + 1);
      const who = turn.speaker ? `${turn.speaker}` : "Line";
      const preview = turn.preview ? `: ${turn.preview}` : "";
      return `${line}. ${who}${preview}`;
    }

    function updateLineSelect(state) {
      const select = document.getElementById("lineSelect");
      const turns = Array.isArray(state.turns) ? state.turns : [];
      const listKey = turns.map(t => `${t.index}:${t.line}:${t.speaker}:${t.preview}`).join("|");
      if (listKey !== lastTurnListKey) {
        lastTurnListKey = listKey;
        select.textContent = "";
        if (!turns.length) {
          const option = document.createElement("option");
          option.value = "";
          option.textContent = "Jump to line...";
          select.appendChild(option);
        } else {
          for (const turn of turns) {
            const option = document.createElement("option");
            option.value = String(turn.index);
            option.textContent = turnOptionLabel(turn);
            select.appendChild(option);
          }
        }
      }
      if (Number.isFinite(state.cue?.index)) {
        select.value = String(state.cue.index);
      }
    }

    async function control(cmd) {
      try {
        const r = await fetch("/" + cmd, { cache: "no-store" });
        const text = await r.text();
        logLine(`${cmd}: ${text.trim()}`);
        await refresh();
      } catch (e) {
        logLine(`${cmd}: ${e}`);
      }
    }

    async function jumpToSelected() {
      const value = document.getElementById("lineSelect").value;
      if (value === "") return;
      await control("jump?index=" + encodeURIComponent(value));
    }

    function updateGainUI(gains) {
      const activeId = document.activeElement?.id || "";
      const global = Number(gains?.global ?? 1);
      const globalText = global.toFixed(2);
      const globalRange = document.getElementById("GlobalGainRange");
      const globalNumber = document.getElementById("GlobalGainNumber");
      if (globalRange && activeId !== "GlobalGainRange") globalRange.value = globalText;
      if (globalNumber && activeId !== "GlobalGainNumber") globalNumber.value = globalText;
      const ducks = gains?.ducks || gains || {};
      for (const id of duckSlots) {
        const balance = Number(ducks?.[id]?.balance ?? ducks?.[id]?.gain ?? 1);
        const effective = Number(ducks?.[id]?.effective ?? (balance * global));
        const text = balance.toFixed(2);
        const range = document.getElementById(id + "GainRange");
        const number = document.getElementById(id + "GainNumber");
        const output = document.getElementById(id + "GainEffective");
        if (range && activeId !== id + "GainRange") range.value = text;
        if (number && activeId !== id + "GainNumber") number.value = text;
        if (output) output.textContent = effective.toFixed(2);
      }
    }

    async function refreshGains() {
      try {
        const r = await fetch("/gain", { cache: "no-store" });
        updateGainUI(await r.json());
      } catch (e) {
        logLine(`gain: ${e}`);
      }
    }

    function gainInput(id, el) {
      const value = Math.max(0, Math.min(8, Number(el.value) || 0));
      const text = value.toFixed(2);
      const range = document.getElementById(id + "GainRange");
      const number = document.getElementById(id + "GainNumber");
      if (range && range !== el) range.value = text;
      if (number && number !== el) number.value = text;
      clearTimeout(gainTimers[id]);
      gainTimers[id] = setTimeout(async () => {
        try {
          const r = await fetch(`/gain?duck=${encodeURIComponent(id)}&value=${encodeURIComponent(text)}`, { cache: "no-store" });
          const body = await r.json();
          updateGainUI(body);
          logLine(`gain ${id}: ${text}x`);
        } catch (e) {
          logLine(`gain ${id}: ${e}`);
        }
      }, 180);
    }

    function globalGainInput(el) {
      const value = Math.max(0, Math.min(8, Number(el.value) || 0));
      const text = value.toFixed(2);
      const range = document.getElementById("GlobalGainRange");
      const number = document.getElementById("GlobalGainNumber");
      if (range && range !== el) range.value = text;
      if (number && number !== el) number.value = text;
      clearTimeout(gainTimers.GLOBAL);
      gainTimers.GLOBAL = setTimeout(async () => {
        try {
          const r = await fetch(`/gain?global=${encodeURIComponent(text)}`, { cache: "no-store" });
          const body = await r.json();
          updateGainUI(body);
          logLine(`global gain: ${text}x`);
        } catch (e) {
          logLine(`global gain: ${e}`);
        }
      }, 180);
    }

    async function refresh() {
      try {
        const r = await fetch("/state", { cache: "no-store" });
        const state = await r.json();
        const cue = state.cue || {};
        const status = parseStatus(state.status || "");
        updateLineSelect(state);
        const cueText = cue.name ? `${cue.name}` : "No cue";
        const cueKey = `${cue.index}:${cue.name}:${cue.generation || 0}`;
        if (cueKey !== lastCue) {
          lastCue = cueKey;
          captureBaselines(status);
          logLine(`${state.playing ? "playing" : "armed"} ${cueText}`);
        }
        document.getElementById("cueName").textContent = cueText;
        document.getElementById("cueMeta").textContent =
          cue.count ? `${cue.index + 1}/${cue.count}  ${Math.round(cue.durationSec || 0)}s` : "--";

        let allOk = true;
        for (const id of duckSlots) {
          const data = status[id] || {};
          if (!data.health || !data.health.startsWith("ok")) allOk = false;
          setHealth(id, data.health);
          document.getElementById(id + "Metrics").innerHTML = metricHTML(id, data);
        }
        const overall = document.getElementById("overall");
        overall.textContent = allOk ? "healthy" : "check ducks";
        overall.className = "status-pill " + (allOk ? "ok" : "bad");

        let pct = cue.durationSec ? Math.min(100, ((cue.elapsedSec || 0) / cue.durationSec) * 100) : 0;
        if (!state.playing && (cue.elapsedSec || 0) === 0) pct = 0;
        document.getElementById("progressFill").style.width = pct.toFixed(1) + "%";
        document.getElementById("progressLabel").textContent =
          `${pct.toFixed(0)}% ${state.playing ? "playing" : "armed"}`;
      } catch (e) {
        const overall = document.getElementById("overall");
        overall.textContent = "offline";
        overall.className = "status-pill bad";
      }
    }

    refresh();
    refreshGains();
    setInterval(refresh, 1000);
    setInterval(refreshGains, 3000);
  </script>
</body>
</html>
"""#

    private static let subtitlesHTML = #"""
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Boy Band Subtitles</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@500;700&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg: #2a2824;
      --fg: #ffffff;
      color-scheme: dark light;
    }
    * { box-sizing: border-box; }
    html, body {
      width: 100%;
      min-height: 100%;
      margin: 0;
    }
    body {
      min-height: 100svh;
      display: grid;
      place-items: center;
      background: var(--bg);
      color: var(--fg);
      font-family: Outfit, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      transition: background-color 260ms ease, color 260ms ease;
      overflow: hidden;
    }
    main {
      width: min(1760px, 92vw);
      min-height: 100svh;
      display: grid;
      place-items: center;
      margin-inline: auto;
      padding: 6vh 4vw;
    }
    .subtitle {
      margin: 0;
      max-width: 26ch;
      text-align: center;
      font-size: clamp(42px, 7.4vw, 136px);
      line-height: 1.04;
      font-weight: 700;
      letter-spacing: 0;
      text-wrap: balance;
      overflow-wrap: break-word;
    }
    .idle .subtitle {
      opacity: .32;
      font-weight: 500;
    }
    @media (max-width: 720px) {
      main { width: 96vw; padding: 5vh 4vw; }
      .subtitle {
        max-width: 18ch;
        font-size: clamp(34px, 11vw, 72px);
        line-height: 1.08;
      }
    }
  </style>
</head>
<body class="idle">
  <main>
    <p id="subtitle" class="subtitle">Ready</p>
  </main>

  <script>
    const themes = {
      pintail: { bg: "#2A2824", fg: "#FFFFFF" },
      classic: { bg: "#ECEA6E", fg: "#000000" },
      mallard: { bg: "#527F16", fg: "#FFFFFF" },
      pekin: { bg: "#EFEFEF", fg: "#000000" }
    };
    const fallback = themes.pintail;
    let lastKey = "";
    let lastLive = null;
    const holdMs = 1200;

    function speakerKey(speaker) {
      return String(speaker || "")
        .toLowerCase()
        .replace(/[^a-z]/g, "");
    }

    function applyTheme(speaker) {
      const key = speakerKey(speaker);
      const theme = themes[key] || fallback;
      document.documentElement.style.setProperty("--bg", theme.bg);
      document.documentElement.style.setProperty("--fg", theme.fg);
    }

    function subtitleChunks(text) {
      const words = String(text || "").trim().match(/\S+/g) || [];
      if (words.length <= 9) return [words.join(" ")];

      const chunks = [];
      let current = [];
      let chars = 0;
      for (const word of words) {
        current.push(word);
        chars += word.length + 1;
        const atPunctuation = /[.!?;:]$/.test(word);
        const atSoftPause = /[,]$/.test(word) && current.length >= 5;
        const fullEnough = current.length >= 7 || chars >= 44;
        if ((atPunctuation && current.length >= 3) || atSoftPause || fullEnough) {
          chunks.push(current.join(" "));
          current = [];
          chars = 0;
        }
      }
      if (current.length) {
        if (chunks.length && current.length <= 2) {
          chunks[chunks.length - 1] += " " + current.join(" ");
        } else {
          chunks.push(current.join(" "));
        }
      }
      return chunks.length ? chunks : [String(text || "").trim()];
    }

    function pacedText(state, text) {
      const cue = state.cue || {};
      const chunks = subtitleChunks(text);
      if (chunks.length <= 1) return chunks[0] || "";
      const duration = Number(cue.durationSec || 0);
      const elapsed = Math.max(0, Number(cue.elapsedSec || 0));
      const progress = duration > 0 ? Math.min(.999, elapsed / duration) : 0;
      const index = Math.max(0, Math.min(chunks.length - 1, Math.floor(progress * chunks.length)));
      return chunks[index];
    }

    function paint(text, speaker, idle) {
      document.body.classList.toggle("idle", Boolean(idle));
      document.getElementById("subtitle").textContent = text || "Ready";
      applyTheme(speaker);
    }

    function updateText(state) {
      const turn = state.turn || {};
      const text = String(turn.text || "").trim();
      const isPlaying = Boolean(state.playing && text);
      if (isPlaying) {
        const live = {
          text: pacedText(state, text),
          speaker: turn.speaker,
          at: Date.now()
        };
        lastLive = live;
        paint(live.text, live.speaker, false);
        return;
      }

      if (lastLive && Date.now() - lastLive.at < holdMs) {
        paint(lastLive.text, lastLive.speaker, false);
        return;
      }

      paint("Ready", turn.speaker, true);
    }

    async function refresh() {
      try {
        const response = await fetch("/state", { cache: "no-store" });
        const state = await response.json();
        const key = [
          state.playing ? "1" : "0",
          state.cue?.generation || 0,
          state.cue?.index || 0,
          Math.floor((Number(state.cue?.elapsedSec || 0)) * 4),
          state.turn?.speaker || "",
          state.turn?.text || ""
        ].join("|");
        if (key !== lastKey) {
          lastKey = key;
          updateText(state);
        }
      } catch {
        document.body.classList.add("idle");
        document.getElementById("subtitle").textContent = "Offline";
        applyTheme("pintail");
      }
    }

    refresh();
    setInterval(refresh, 250);
  </script>
</body>
</html>
"""#

    private static let qaHTML = #"""
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Duck Q&A</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@500;700&display=swap" rel="stylesheet">
  <style>
    :root {
      color-scheme: dark light;
      --bg: #E69F24;
      --fg: #000000;
      --muted: rgba(0, 0, 0, .58);
      --line: rgba(0, 0, 0, .28);
      --field: rgba(0, 0, 0, .08);
      --field-focus: rgba(0, 0, 0, .13);
    }
    * { box-sizing: border-box; }
    html, body {
      width: 100%;
      min-height: 100%;
      margin: 0;
    }
    body {
      min-height: 100svh;
      background: var(--bg);
      color: var(--fg);
      font-family: Outfit, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      transition: background-color 260ms ease, color 260ms ease;
      overflow: hidden;
    }
    button, textarea {
      font: inherit;
      color: inherit;
    }
    .screen {
      min-height: 100svh;
      width: 100%;
      padding: 6vh 5vw;
      display: grid;
      place-items: center;
    }
    body[data-mode="answer"] #inputScreen,
    body[data-mode="input"] #answerScreen,
    body[data-mode="start"] #inputScreen,
    body[data-mode="start"] #answerScreen,
    body[data-mode="video"] #inputScreen,
    body[data-mode="video"] #answerScreen,
    body[data-mode="input"] #startScreen,
    body[data-mode="answer"] #startScreen,
    body[data-mode="video"] #startScreen,
    body:not([data-mode="video"]) #videoScreen {
      display: none;
    }
    body[data-mode="start"] #startScreen,
    body[data-mode="video"] #videoScreen {
      display: grid;
    }
    .ask {
      width: min(980px, 92vw);
      display: grid;
      grid-template-columns: 1fr;
      gap: 18px;
      justify-items: center;
    }
    .field {
      width: 100%;
      display: grid;
      gap: 8px;
    }
    textarea {
      width: 100%;
      min-height: 118px;
      max-height: 48svh;
      resize: none;
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 18px 20px;
      background: var(--field);
      outline: none;
      font-size: clamp(24px, 4vw, 52px);
      line-height: 1.1;
      letter-spacing: 0;
      overflow-wrap: break-word;
      overflow-y: auto;
    }
    textarea:focus {
      background: var(--field-focus);
      border-color: var(--fg);
    }
    textarea::placeholder {
      color: var(--muted);
    }
    .buttons {
      display: flex;
      justify-content: center;
      gap: 14px;
    }
    button {
      min-width: 58px;
      height: 58px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: var(--field);
      cursor: pointer;
      display: grid;
      place-items: center;
      padding: 0;
      line-height: 1;
    }
    button svg {
      width: 28px;
      height: 28px;
      display: block;
      fill: none;
      stroke: currentColor;
      stroke-width: 2.4;
      stroke-linecap: round;
      stroke-linejoin: round;
    }
    button.primary {
      background: var(--fg);
      color: var(--bg);
      border-color: var(--fg);
    }
    button:disabled {
      opacity: .55;
      cursor: default;
    }
    .status {
      color: var(--muted);
      font-size: clamp(16px, 2vw, 22px);
      min-height: 1.2em;
      text-align: center;
    }
    .answer {
      width: min(1760px, 92vw);
      min-height: 100svh;
      display: grid;
      place-items: center;
      margin-inline: auto;
      padding: 6vh 4vw;
    }
    .subtitle {
      margin: 0;
      max-width: 26ch;
      text-align: center;
      font-size: clamp(42px, 7.4vw, 136px);
      line-height: 1.04;
      font-weight: 700;
      letter-spacing: 0;
      text-wrap: balance;
      overflow-wrap: break-word;
    }
    .answer-idle .subtitle {
      opacity: .42;
      font-weight: 500;
    }
    .answer-actions {
      position: fixed;
      right: 24px;
      bottom: 24px;
      display: flex;
      gap: 10px;
      opacity: .72;
    }
    body[data-show="true"][data-mode="answer"] .answer-actions {
      display: none;
    }
    .answer-actions button {
      width: auto;
      min-width: 58px;
      padding: 0 18px;
      font-size: 18px;
    }
    .start-screen {
      min-height: 100svh;
      width: 100%;
      place-items: center;
      padding: 6vh 5vw;
    }
    .start-button {
      width: 92px;
      height: 92px;
      border-radius: 8px;
      background: var(--fg);
      color: var(--bg);
      border-color: var(--fg);
    }
    .start-button svg {
      width: 42px;
      height: 42px;
    }
    .video-screen {
      position: fixed;
      inset: 0;
      width: 100vw;
      height: 100svh;
      background: #000;
      place-items: center;
      z-index: 10;
    }
    .handoff-video {
      width: 100vw;
      height: 100svh;
      object-fit: contain;
      background: #000;
    }
    @media (max-width: 760px) {
      .screen { padding: 5vh 4vw; }
      textarea {
        min-height: 160px;
        font-size: clamp(26px, 9vw, 48px);
      }
      .answer {
        width: 96vw;
        padding: 5vh 4vw;
      }
      .subtitle {
        max-width: 18ch;
        font-size: clamp(34px, 11vw, 72px);
        line-height: 1.08;
      }
    }
  </style>
</head>
<body data-mode="input">
  <section id="startScreen" class="start-screen">
    <button id="startShowBtn" class="start-button" type="button" title="Start show" aria-label="Start show">
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path d="M5 12h14"></path>
        <path d="m13 6 6 6-6 6"></path>
      </svg>
    </button>
  </section>

  <section id="inputScreen" class="screen" tabindex="-1">
    <form id="qaForm" class="ask" method="get" action="/qa/ask">
      <label class="field">
        <textarea id="question" name="question" placeholder="Ask the ducks..." autocomplete="off"></textarea>
        <span id="status" class="status"></span>
      </label>
      <div class="buttons">
        <button id="listenBtn" type="button" title="Listen" aria-label="Listen" disabled>
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M12 3a3 3 0 0 0-3 3v6a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3Z"></path>
            <path d="M19 10v2a7 7 0 0 1-14 0v-2"></path>
            <path d="M12 19v3"></path>
          </svg>
        </button>
        <button class="primary" id="askBtn" type="submit" title="Ask ducks" aria-label="Ask ducks">
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M5 12h14"></path>
            <path d="m13 6 6 6-6 6"></path>
          </svg>
        </button>
      </div>
    </form>
  </section>

  <section id="answerScreen" class="answer answer-idle">
    <p id="subtitle" class="subtitle">Thinking</p>
    <div class="answer-actions">
      <button id="backBtn" type="button" title="Ask another question">Ask</button>
    </div>
  </section>

  <section id="videoScreen" class="video-screen">
    <video id="handoffVideo" class="handoff-video" src="/handoff-video.mp4" preload="auto" playsinline></video>
  </section>

  <script src="/qa.js?v=20260602-show-video"></script>
</body>
</html>
"""#

    private static let handoffVideoPath = "/Users/jfizel/Downloads/ok_now_let_s_try_the_video_on.mp4"

    private static var showHTML: String {
        qaHTML.replacingOccurrences(of: "<body data-mode=\"input\">",
                                    with: "<body data-mode=\"start\" data-show=\"true\">")
    }

    private static func qaFrameHTML(_ text: String) -> String {
        """
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <style>
    body {
      margin: 12px;
      background: #0d1012;
      color: #a8b4b0;
      font: 16px/1.4 system-ui, sans-serif;
      white-space: pre-wrap;
    }
  </style>
</head>
<body>\(htmlEscape(text.trimmingCharacters(in: .whitespacesAndNewlines)))</body>
</html>
"""
    }

    private static let qaJS = #"""
(() => {
  const themes = {
    input: { bg: "#E69F24", fg: "#000000" },
    pintail: { bg: "#2A2824", fg: "#FFFFFF" },
    classic: { bg: "#ECEA6E", fg: "#000000" },
    mallard: { bg: "#527F16", fg: "#FFFFFF" },
    pekin: { bg: "#EFEFEF", fg: "#000000" }
  };
  const fallback = themes.pintail;
  const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
  const question = document.getElementById("question");
  const status = document.getElementById("status");
  const form = document.getElementById("qaForm");
  const inputScreen = document.getElementById("inputScreen");
  const startShowBtn = document.getElementById("startShowBtn");
  const listenBtn = document.getElementById("listenBtn");
  const askBtn = document.getElementById("askBtn");
  const backBtn = document.getElementById("backBtn");
  const answerScreen = document.getElementById("answerScreen");
  const subtitle = document.getElementById("subtitle");
  const handoffVideo = document.getElementById("handoffVideo");
  const showMode = document.body.dataset.show === "true";
  let lastKey = "";
  let lastLive = null;
  let watchingAnswer = false;
  let watchingShow = false;
  let sawScriptPlaying = false;
  let sawFinalScriptLinePlaying = false;
  let videoStarted = false;
  let questionStartedAt = 0;
  let autoReturnTimer = null;
  const holdMs = 1800;

  function setStatus(text, bad = false) {
    status.textContent = text;
    status.style.color = bad ? "#ffb0aa" : "var(--muted)";
  }

    function setIdleStatus() {
      if (SpeechRecognition) {
      setStatus("");
      } else {
        setStatus("");
      }
    }

  function setBusy(busy) {
    askBtn.disabled = busy;
    listenBtn.disabled = busy || !SpeechRecognition;
  }

  function resizeQuestion() {
    question.style.height = "auto";
    question.style.height = Math.min(question.scrollHeight, Math.round(window.innerHeight * 0.48)) + "px";
  }

  function speakerKey(speaker) {
    return String(speaker || "").toLowerCase().replace(/[^a-z]/g, "");
  }

  function applyTheme(speaker) {
    const theme = themes[speakerKey(speaker)] || fallback;
    document.documentElement.style.setProperty("--bg", theme.bg);
    document.documentElement.style.setProperty("--fg", theme.fg);
    document.documentElement.style.setProperty("--muted", theme.fg === "#000000" ? "rgba(0, 0, 0, .58)" : "rgba(255, 255, 255, .66)");
    document.documentElement.style.setProperty("--line", theme.fg === "#000000" ? "rgba(0, 0, 0, .28)" : "rgba(255, 255, 255, .34)");
    document.documentElement.style.setProperty("--field", theme.fg === "#000000" ? "rgba(0, 0, 0, .08)" : "rgba(255, 255, 255, .12)");
    document.documentElement.style.setProperty("--field-focus", theme.fg === "#000000" ? "rgba(0, 0, 0, .13)" : "rgba(255, 255, 255, .18)");
  }

  function setMode(mode) {
    document.body.dataset.mode = mode;
    if (mode === "input") {
      applyTheme("input");
      answerScreen.classList.add("answer-idle");
      window.requestAnimationFrame(() => {
        question.blur();
        inputScreen.focus({ preventScroll: true });
      });
    }
  }

  function subtitleChunks(text) {
    const words = String(text || "").trim().match(/\S+/g) || [];
    if (words.length <= 9) return [words.join(" ")];
    const chunks = [];
    let current = [];
    let chars = 0;
    for (const word of words) {
      current.push(word);
      chars += word.length + 1;
      const atPunctuation = /[.!?;:]$/.test(word);
      const atSoftPause = /[,]$/.test(word) && current.length >= 5;
      const fullEnough = current.length >= 7 || chars >= 44;
      if ((atPunctuation && current.length >= 3) || atSoftPause || fullEnough) {
        chunks.push(current.join(" "));
        current = [];
        chars = 0;
      }
    }
    if (current.length) {
      if (chunks.length && current.length <= 2) chunks[chunks.length - 1] += " " + current.join(" ");
      else chunks.push(current.join(" "));
    }
    return chunks.length ? chunks : [String(text || "").trim()];
  }

  function pacedText(state, text) {
    const cue = state.cue || {};
    const chunks = subtitleChunks(text);
    if (chunks.length <= 1) return chunks[0] || "";
    const duration = Number(cue.durationSec || 0);
    const elapsed = Math.max(0, Number(cue.elapsedSec || 0));
    const progress = duration > 0 ? Math.min(.999, elapsed / duration) : 0;
    const index = Math.max(0, Math.min(chunks.length - 1, Math.floor(progress * chunks.length)));
    return chunks[index];
  }

  function paintAnswer(text, speaker, idle = false) {
    answerScreen.classList.toggle("answer-idle", Boolean(idle));
    subtitle.textContent = text || "Thinking";
    applyTheme(speaker);
  }

  function backToInput(clearQuestion = false) {
    watchingAnswer = false;
    watchingShow = false;
    if (autoReturnTimer) {
      clearTimeout(autoReturnTimer);
      autoReturnTimer = null;
    }
    if (clearQuestion) {
      question.value = "";
      resizeQuestion();
    }
    setBusy(false);
    setIdleStatus();
    setMode("input");
  }

  async function primeVideo() {
    if (!handoffVideo) return;
    try {
      handoffVideo.muted = false;
      await handoffVideo.play();
      handoffVideo.pause();
      handoffVideo.currentTime = 0;
    } catch {
      handoffVideo.currentTime = 0;
    }
  }

  async function startShow() {
    watchingAnswer = false;
    watchingShow = true;
    sawScriptPlaying = false;
    sawFinalScriptLinePlaying = false;
    videoStarted = false;
    lastKey = "";
    lastLive = null;
    setMode("answer");
    paintAnswer(" ", "input", true);
    await primeVideo();
    try {
      const r = await fetch("/play", { cache: "no-store" });
      const body = await r.text();
      if (!r.ok) {
        watchingShow = false;
        paintAnswer(body.trim() || "Show failed", "pintail", true);
      }
    } catch {
      watchingShow = false;
      paintAnswer("Show failed", "pintail", true);
    }
  }

  async function playHandoffVideo() {
    if (videoStarted) return;
    videoStarted = true;
    watchingShow = false;
    setMode("video");
    if (!handoffVideo) {
      backToInput(true);
      return;
    }
    try {
      handoffVideo.controls = false;
      handoffVideo.muted = false;
      handoffVideo.currentTime = 0;
      await handoffVideo.play();
    } catch {
      handoffVideo.controls = true;
    }
  }

  function listen() {
    if (!SpeechRecognition) {
      setIdleStatus();
      return;
    }
    const rec = new SpeechRecognition();
    rec.lang = "en-US";
    rec.interimResults = true;
    rec.continuous = false;
    setBusy(true);
    setStatus("Listening...");
    let finalText = "";
    rec.onresult = event => {
      let interim = "";
      for (let i = event.resultIndex; i < event.results.length; i++) {
        const transcript = event.results[i][0].transcript;
        if (event.results[i].isFinal) finalText += transcript;
        else interim += transcript;
      }
      question.value = (finalText || interim).trim();
      resizeQuestion();
    };
    rec.onerror = event => {
      setBusy(false);
      setStatus("Mic error: " + event.error, true);
    };
    rec.onend = () => {
      setBusy(false);
      setStatus(question.value.trim() ? "Question captured." : "No question captured.", !question.value.trim());
      if (question.value.trim()) question.focus();
    };
    rec.start();
  }

  function updateAnswer(state) {
    if (!watchingAnswer) return;
    const turn = state.turn || {};
    const cue = state.cue || {};
    const text = String(turn.text || "").trim();
    const hasQuestion = Boolean(String(turn.question || "").trim());
    const isCurrentQuestion = hasQuestion || Date.now() - questionStartedAt < 45000;
    const isPlaying = Boolean(state.playing && text && isCurrentQuestion);
    const isFinalLine = Number(cue.count || 0) > 0 && Number(cue.index || 0) >= Number(cue.count || 0) - 1;

    if (isPlaying) {
      if (autoReturnTimer) {
        clearTimeout(autoReturnTimer);
        autoReturnTimer = null;
      }
      const live = {
        text: pacedText(state, text),
        speaker: turn.speaker,
        at: Date.now()
      };
      lastLive = live;
      paintAnswer(live.text, live.speaker, false);
      return;
    }

    if (text && hasQuestion && isFinalLine) {
      paintAnswer(lastLive?.text || text, turn.speaker, false);
      if (!autoReturnTimer) {
        autoReturnTimer = setTimeout(() => backToInput(true), 300);
      }
      return;
    }

    if (lastLive && Date.now() - lastLive.at < holdMs) {
      paintAnswer(lastLive.text, lastLive.speaker, false);
      return;
    }

    if (text && hasQuestion) {
      paintAnswer(text, turn.speaker, true);
      return;
    }

    paintAnswer("Thinking", "input", true);
  }

  async function refreshAnswer() {
    if (!watchingAnswer) return;
    try {
      const response = await fetch("/state", { cache: "no-store" });
      const state = await response.json();
      const key = [
        state.playing ? "1" : "0",
        state.cue?.generation || 0,
        state.cue?.index || 0,
        Math.floor((Number(state.cue?.elapsedSec || 0)) * 4),
        state.turn?.speaker || "",
        state.turn?.text || "",
        state.turn?.question || ""
      ].join("|");
      if (key !== lastKey) {
        lastKey = key;
        updateAnswer(state);
      }
    } catch {
      paintAnswer("Offline", "pintail", true);
    }
  }

  async function refreshShow() {
    if (!watchingShow || videoStarted) return;
    try {
      const response = await fetch("/state", { cache: "no-store" });
      const state = await response.json();
      const turn = state.turn || {};
      const cue = state.cue || {};
      const text = String(turn.text || "").trim();
      const isQA = Boolean(String(turn.question || "").trim());
      const hasScriptLine = Boolean(text && !isQA && Number(cue.count || 0) > 0);
      const isFinalLine = hasScriptLine && Number(cue.index || 0) >= Number(cue.count || 0) - 1;

      if (state.playing && hasScriptLine) {
        sawScriptPlaying = true;
        if (isFinalLine) sawFinalScriptLinePlaying = true;
        const live = {
          text: pacedText(state, text),
          speaker: turn.speaker,
          at: Date.now()
        };
        lastLive = live;
        paintAnswer(live.text, live.speaker, false);
        return;
      }

      if (sawFinalScriptLinePlaying && isFinalLine) {
        await playHandoffVideo();
        return;
      }

      if (lastLive) {
        paintAnswer(lastLive.text, lastLive.speaker, false);
        return;
      }

      paintAnswer(" ", "input", true);
    } catch {
      paintAnswer("Offline", "pintail", true);
    }
  }

  async function ask(event) {
    event.preventDefault();
    const text = question.value.trim();
    if (!text) {
      setStatus("Type or capture a question first.", true);
      return;
    }
    lastKey = "";
    lastLive = null;
    watchingAnswer = true;
    if (autoReturnTimer) {
      clearTimeout(autoReturnTimer);
      autoReturnTimer = null;
    }
    questionStartedAt = Date.now();
    setBusy(true);
    setMode("answer");
    paintAnswer("Thinking", "input", true);
    try {
      const r = await fetch("/qa/ask?question=" + encodeURIComponent(text), { cache: "no-store" });
      const body = await r.text();
      if (!body.trim().startsWith("answering:")) {
        paintAnswer(body.trim() || "Q&A failed", "pintail", true);
      }
      await refreshAnswer();
    } catch (e) {
      paintAnswer("Q&A failed", "pintail", true);
      setStatus("Q&A failed: " + e, true);
    } finally {
      setBusy(false);
    }
  }

  question.addEventListener("keydown", event => {
    if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
      event.preventDefault();
      form.requestSubmit();
    } else if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();
      form.requestSubmit();
    } else if (event.key === " " && !question.value.trim() && !listenBtn.disabled) {
      event.preventDefault();
      listen();
    }
  });
  question.addEventListener("input", resizeQuestion);
  window.addEventListener("resize", resizeQuestion);

  document.addEventListener("keydown", event => {
    if (event.key === "Escape") {
      event.preventDefault();
      if (document.body.dataset.mode === "answer") backToInput();
      else {
        question.value = "";
        resizeQuestion();
      }
    }
    if (event.key === " " && document.body.dataset.mode === "input" && document.activeElement !== question) {
      event.preventDefault();
      if (!listenBtn.disabled) listen();
    }
    if (event.key === "/" && document.body.dataset.mode === "input" && document.activeElement !== question) {
      event.preventDefault();
      question.focus();
    }
  });

  listenBtn.addEventListener("click", listen);
  form.addEventListener("submit", ask);
  backBtn.addEventListener("click", backToInput);
  startShowBtn.addEventListener("click", startShow);
  handoffVideo.addEventListener("ended", () => backToInput(true));
  setIdleStatus();
  setBusy(false);
  if (showMode) {
    setMode("start");
  } else {
    setMode("input");
  }
  resizeQuestion();
  setInterval(() => {
    refreshAnswer();
    refreshShow();
  }, 250);
})();
"""#

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
