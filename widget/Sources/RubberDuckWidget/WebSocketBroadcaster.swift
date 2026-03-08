// WebSocket Broadcaster — Fanout messaging to all connected WebSocket clients.
//
// Port of service/broadcast.py. Manages connected WebSocket outbound writers
// from Hummingbird and broadcasts JSON messages to all of them.

import Foundation
import HummingbirdWebSocket
import NIOCore

actor WebSocketBroadcaster {

    private var connections: [UUID: WebSocketOutboundWriter] = [:]

    var clientCount: Int { connections.count }

    // MARK: - Client Management

    func add(_ writer: WebSocketOutboundWriter) -> UUID {
        let id = UUID()
        connections[id] = writer
        print("[ws] Client connected (\(connections.count) total)")
        return id
    }

    func remove(_ id: UUID) {
        connections.removeValue(forKey: id)
        print("[ws] Client disconnected (\(connections.count) total)")
    }

    // MARK: - Broadcast

    /// Send a JSON-encoded message to all connected WebSocket clients.
    func broadcast<T: Encodable>(_ data: T) async {
        guard let jsonData = try? JSONEncoder().encode(data),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        var dead = Set<UUID>()
        for (id, writer) in connections {
            do {
                try await writer.write(.text(jsonString))
            } catch {
                dead.insert(id)
            }
        }
        for id in dead {
            connections.removeValue(forKey: id)
        }
    }

    /// Send a raw JSON string to all connected WebSocket clients.
    func broadcastRaw(_ jsonString: String) async {
        var dead = Set<UUID>()
        for (id, writer) in connections {
            do {
                try await writer.write(.text(jsonString))
            } catch {
                dead.insert(id)
            }
        }
        for id in dead {
            connections.removeValue(forKey: id)
        }
    }
}
