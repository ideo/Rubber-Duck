// Mini Server — Lightweight HTTP + WebSocket server using Network.framework.
//
// Replaces Hummingbird/NIO with zero external dependencies. Uses NWListener
// for TCP, hand-parses HTTP/1.1, and implements RFC 6455 WebSocket framing.
// Designed for localhost-only traffic at ~2 requests/minute.

import Foundation
import Network
import CryptoKit

// MARK: - HTTP Types

struct HTTPRequest: Sendable {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data
}

struct HTTPResponse: Sendable {
    let status: Int
    let statusText: String
    let headers: [String: String]
    let body: Data

    init(status: Int = 200, statusText: String = "OK",
         headers: [String: String] = [:], body: Data = Data()) {
        self.status = status
        self.statusText = statusText
        self.headers = headers
        self.body = body
    }

    static func json(_ data: Data) -> HTTPResponse {
        HTTPResponse(headers: ["Content-Type": "application/json"], body: data)
    }

    static func json(_ dict: [String: Any]) -> HTTPResponse {
        let data = (try? JSONSerialization.data(withJSONObject: dict)) ?? Data()
        return .json(data)
    }

    static func html(_ content: String) -> HTTPResponse {
        HTTPResponse(headers: ["Content-Type": "text/html; charset=utf-8"],
                     body: Data(content.utf8))
    }

    static func badRequest(_ message: String = "invalid") -> HTTPResponse {
        HTTPResponse(status: 400, statusText: "Bad Request",
                     headers: ["Content-Type": "application/json"],
                     body: Data("{\"error\":\"\(message)\"}".utf8))
    }

    static let notFound = HTTPResponse(status: 404, statusText: "Not Found")

    /// Serialize to raw HTTP/1.1 response bytes.
    func encoded() -> Data {
        var line = "HTTP/1.1 \(status) \(statusText)\r\n"
        var hdrs = headers
        hdrs["Content-Length"] = "\(body.count)"
        hdrs["Connection"] = "close"
        for (k, v) in hdrs { line += "\(k): \(v)\r\n" }
        line += "\r\n"
        var data = Data(line.utf8)
        data.append(body)
        return data
    }
}

// MARK: - WebSocket Connection

/// A live WebSocket connection wrapping an NWConnection.
final class WSConnection: @unchecked Sendable {
    let id: UUID
    let connection: NWConnection

    init(id: UUID = UUID(), connection: NWConnection) {
        self.id = id
        self.connection = connection
    }

    /// Send a text frame to this WebSocket client.
    func sendText(_ text: String) {
        let frame = WSFrame.encodeText(Data(text.utf8))
        connection.send(content: frame, completion: .idempotent)
    }
}

// MARK: - WebSocket Frame Codec

enum WSFrame {
    /// Encode a server→client text frame (unmasked, per RFC 6455).
    static func encodeText(_ payload: Data) -> Data {
        var frame = Data()
        frame.append(0x81) // FIN + text opcode
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
    /// Returns (opcode, payload, bytesConsumed) or nil if buffer is incomplete.
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
            for i in 0..<8 {
                payloadLen = (payloadLen << 8) | Int(data[2 + i])
            }
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
            for i in 0..<payload.count {
                payload[i] ^= mask[i % 4]
            }
        }

        return (opcode, payload, totalFrame)
    }
}

// MARK: - Mini HTTP + WebSocket Server

typealias RouteHandler = @Sendable (HTTPRequest) async -> HTTPResponse

final class MiniServer {
    private var listener: NWListener?
    private var routes: [(method: String, path: String, handler: RouteHandler)] = []

    // WebSocket handlers
    private var wsPath: String?
    private var onWSConnect: (@Sendable (WSConnection) -> Void)?
    private var onWSMessage: (@Sendable (WSConnection, String) async -> Void)?
    private var onWSDisconnect: (@Sendable (WSConnection) -> Void)?

    private(set) var port: UInt16
    private let queue = DispatchQueue(label: "duck.miniserver")

    init(port: UInt16) {
        self.port = port
    }

    // MARK: - Route Registration

    func get(_ path: String, handler: @escaping RouteHandler) {
        routes.append(("GET", path, handler))
    }

    func post(_ path: String, handler: @escaping RouteHandler) {
        routes.append(("POST", path, handler))
    }

    func websocket(
        _ path: String,
        onConnect: @escaping @Sendable (WSConnection) -> Void,
        onMessage: @escaping @Sendable (WSConnection, String) async -> Void,
        onDisconnect: @escaping @Sendable (WSConnection) -> Void
    ) {
        wsPath = path
        onWSConnect = onConnect
        onWSMessage = onMessage
        onWSDisconnect = onDisconnect
    }

    // MARK: - Lifecycle

    func start() throws {
        // Try preferred port, then fallback to next available ports
        let portsToTry: [UInt16] = [port] + (1...10).map { port + $0 }

        for candidate in portsToTry {
            do {
                let params = NWParameters.tcp
                params.allowLocalEndpointReuse = true
                let l = try NWListener(using: params, on: NWEndpoint.Port(rawValue: candidate)!)

                l.newConnectionHandler = { [weak self] conn in
                    self?.accept(conn)
                }
                l.stateUpdateHandler = { state in
                    if case .failed(let err) = state {
                        DuckLog.log("[server] Listener error on port \(candidate): \(err)")
                    }
                }

                listener = l
                l.start(queue: queue)
                port = candidate
                if candidate != portsToTry[0] {
                    DuckLog.log("[server] Port \(portsToTry[0]) in use, bound to \(candidate)")
                }
                // Write port file so hooks can find us
                DuckConfig.activePort = Int(candidate)
                DuckConfig.writePortFile()
                return
            } catch {
                DuckLog.log("[server] Port \(candidate) unavailable: \(error)")
                continue
            }
        }
        // All preferred ports failed — let the OS pick any available port
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            let l = try NWListener(using: params)  // no port = OS auto-assigns

            l.newConnectionHandler = { [weak self] conn in
                self?.accept(conn)
            }
            l.stateUpdateHandler = { [weak self] state in
                if case .ready = state, let actualPort = l.port?.rawValue {
                    self?.port = actualPort
                    DuckConfig.activePort = Int(actualPort)
                    DuckConfig.writePortFile()
                    DuckLog.log("[server] OS assigned port \(actualPort)")
                } else if case .failed(let err) = state {
                    DuckLog.log("[server] Listener error on OS-assigned port: \(err)")
                }
            }

            listener = l
            l.start(queue: queue)
            DuckLog.log("[server] Ports \(portsToTry.first!)–\(portsToTry.last!) all taken, using OS-assigned port")
            return
        } catch {
            throw error
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Connection Handling

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        readHTTP(connection: connection, buffer: Data())
    }

    private func readHTTP(connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) {
            [weak self] data, _, isComplete, error in
            guard let self, let data else {
                connection.cancel()
                return
            }

            var buf = buffer
            buf.append(data)

            // Look for end of HTTP headers (\r\n\r\n)
            guard let headerEnd = buf.findCRLFCRLF() else {
                if !isComplete {
                    self.readHTTP(connection: connection, buffer: buf)
                } else {
                    connection.cancel()
                }
                return
            }

            // Parse request line + headers
            let headerData = Data(buf[0..<headerEnd])
            guard let headerStr = String(data: headerData, encoding: .utf8),
                  let parsed = self.parseHeaders(headerStr) else {
                connection.cancel()
                return
            }

            let bodyStart = headerEnd + 4  // skip \r\n\r\n
            let contentLength = Int(parsed.headers["content-length"] ?? "0") ?? 0
            let bodyAvailable = buf.count - bodyStart

            if bodyAvailable >= contentLength {
                let body = contentLength > 0
                    ? Data(buf[bodyStart..<(bodyStart + contentLength)])
                    : Data()
                let request = HTTPRequest(method: parsed.method, path: parsed.path,
                                          headers: parsed.headers, body: body)
                self.route(request, connection: connection)
            } else {
                // Need more body data
                self.readBody(connection: connection, buffer: buf,
                              bodyStart: bodyStart, contentLength: contentLength,
                              parsed: parsed)
            }
        }
    }

    private func readBody(connection: NWConnection, buffer: Data,
                          bodyStart: Int, contentLength: Int,
                          parsed: (method: String, path: String, headers: [String: String])) {
        let needed = contentLength - (buffer.count - bodyStart)
        connection.receive(minimumIncompleteLength: needed, maximumLength: max(needed, 65536)) {
            [weak self] data, _, _, _ in
            guard let self, let data else {
                connection.cancel()
                return
            }

            var buf = buffer
            buf.append(data)
            let bodyAvailable = buf.count - bodyStart

            if bodyAvailable >= contentLength {
                let body = Data(buf[bodyStart..<(bodyStart + contentLength)])
                let request = HTTPRequest(method: parsed.method, path: parsed.path,
                                          headers: parsed.headers, body: body)
                self.route(request, connection: connection)
            } else {
                self.readBody(connection: connection, buffer: buf,
                              bodyStart: bodyStart, contentLength: contentLength,
                              parsed: parsed)
            }
        }
    }

    // MARK: - Parsing

    private func parseHeaders(_ raw: String) -> (method: String, path: String, headers: [String: String])? {
        let lines = raw.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ", maxSplits: 2)
        guard parts.count >= 2 else { return nil }

        let method = String(parts[0])
        let path = String(parts[1])

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[line.startIndex..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }

        return (method, path, headers)
    }

    // MARK: - Routing

    private func route(_ request: HTTPRequest, connection: NWConnection) {
        // WebSocket upgrade?
        if request.path == wsPath,
           request.headers["upgrade"]?.lowercased() == "websocket",
           let key = request.headers["sec-websocket-key"] {
            upgradeWebSocket(connection: connection, key: key)
            return
        }

        // Match registered route (strip query string for comparison)
        let pathOnly = request.path.components(separatedBy: "?").first ?? request.path
        for r in routes where r.method == request.method && r.path == pathOnly {
            let handler = r.handler
            Task {
                let response = await handler(request)
                self.send(response, on: connection)
            }
            return
        }

        // 404
        send(.notFound, on: connection)
    }

    private func send(_ response: HTTPResponse, on connection: NWConnection) {
        connection.send(content: response.encoded(), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    // MARK: - WebSocket Upgrade

    private func upgradeWebSocket(connection: NWConnection, key: String) {
        let accept = wsAcceptKey(key)
        let handshake = "HTTP/1.1 101 Switching Protocols\r\n" +
            "Upgrade: websocket\r\n" +
            "Connection: Upgrade\r\n" +
            "Sec-WebSocket-Accept: \(accept)\r\n\r\n"

        connection.send(content: Data(handshake.utf8), completion: .contentProcessed { [weak self] _ in
            guard let self else { return }
            let ws = WSConnection(connection: connection)
            self.onWSConnect?(ws)
            self.readWSFrames(ws: ws, buffer: Data())
        })
    }

    private func readWSFrames(ws: WSConnection, buffer: Data) {
        ws.connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) {
            [weak self] data, _, isComplete, error in
            guard let self else { return }

            guard error == nil, let data else {
                self.onWSDisconnect?(ws)
                return
            }

            var buf = buffer
            buf.append(data)

            // Process all complete frames in buffer
            while let frame = WSFrame.decode(buf) {
                buf = Data(buf.dropFirst(frame.consumed))

                switch frame.opcode {
                case 0x1: // Text
                    if let text = String(data: frame.payload, encoding: .utf8) {
                        let handler = self.onWSMessage
                        Task { await handler?(ws, text) }
                    }
                case 0x8: // Close
                    ws.connection.send(content: Data([0x88, 0x00]),
                                       completion: .contentProcessed { _ in
                        ws.connection.cancel()
                    })
                    self.onWSDisconnect?(ws)
                    return
                case 0x9: // Ping → Pong
                    var pongFrame = Data([0x8A]) // FIN + pong opcode
                    let pPayload = frame.payload
                    if pPayload.count < 126 {
                        pongFrame.append(UInt8(pPayload.count))
                    }
                    pongFrame.append(pPayload)
                    ws.connection.send(content: pongFrame, completion: .idempotent)
                default:
                    break
                }
            }

            if !isComplete {
                self.readWSFrames(ws: ws, buffer: buf)
            } else {
                self.onWSDisconnect?(ws)
            }
        }
    }

    /// Compute Sec-WebSocket-Accept per RFC 6455.
    private func wsAcceptKey(_ clientKey: String) -> String {
        let magic = clientKey + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        let hash = Insecure.SHA1.hash(data: Data(magic.utf8))
        return Data(hash).base64EncodedString()
    }
}

// MARK: - Data Extension

private extension Data {
    /// Find the byte offset of \r\n\r\n in the data, or nil if not found.
    func findCRLFCRLF() -> Int? {
        guard count >= 4 else { return nil }
        for i in 0..<(count - 3) {
            if self[i] == 0x0D && self[i+1] == 0x0A &&
               self[i+2] == 0x0D && self[i+3] == 0x0A {
                return i
            }
        }
        return nil
    }
}
