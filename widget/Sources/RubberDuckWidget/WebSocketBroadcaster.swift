// WebSocket Broadcaster — Fanout messaging to all connected WebSocket clients.
//
// Manages connected WSConnection instances and broadcasts JSON messages to all.

import Foundation

actor WebSocketBroadcaster {

    private var connections: [UUID: WSConnection] = [:]

    var clientCount: Int { connections.count }

    // MARK: - Client Management

    func add(_ ws: WSConnection) -> UUID {
        connections[ws.id] = ws
        print("[ws] Client connected (\(connections.count) total)")
        return ws.id
    }

    func remove(_ id: UUID) {
        connections.removeValue(forKey: id)
        print("[ws] Client disconnected (\(connections.count) total)")
    }

    // MARK: - Broadcast

    /// Send a JSON-encoded message to all connected WebSocket clients.
    func broadcast<T: Encodable>(_ data: T) {
        guard let jsonData = try? JSONEncoder().encode(data),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        for (_, ws) in connections {
            ws.sendText(jsonString)
        }
    }

    /// Send a raw JSON string to all connected WebSocket clients.
    func broadcastRaw(_ jsonString: String) {
        for (_, ws) in connections {
            ws.sendText(jsonString)
        }
    }
}
