// WebSocket Transport — EvalTransport implementation using URLSession WebSocket.
//
// Connects to the eval service at a given URL, decodes inbound messages
// via InboundMessage, and encodes outbound messages via OutboundMessage.
// Includes automatic reconnection on disconnect.

import Foundation

class WebSocketTransport: EvalTransport {
    private(set) var isConnected: Bool = false
    var onMessage: ((InboundMessage) -> Void)?

    private var webSocketTask: URLSessionWebSocketTask?
    private var reconnectTask: Task<Void, Never>?
    private let url: URL

    /// Connect to a remote eval service. For local use, prefer LocalEvalTransport.
    init(url: URL = URL(string: "ws://localhost:\(DuckConfig.activePort)/ws")!) {
        self.url = url
    }

    deinit {
        reconnectTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }

    func connect() {
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = true
        receiveMessage()
        startReconnectLoop()
    }

    func disconnect() {
        reconnectTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        isConnected = false
    }

    func send(_ message: OutboundMessage) {
        guard let text = message.encode() else { return }
        webSocketTask?.send(.string(text)) { error in
            if let error = error {
                print("[ws] Send error: \(error)")
            }
        }
    }

    // MARK: - Receive

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                let text: String?
                switch message {
                case .string(let s):
                    text = s
                case .data(let data):
                    text = String(data: data, encoding: .utf8)
                @unknown default:
                    text = nil
                }
                if let text = text, let msg = InboundMessage.decode(from: text) {
                    self.onMessage?(msg)
                }
                self.receiveMessage()

            case .failure:
                self.isConnected = false
            }
        }
    }

    // MARK: - Reconnect

    private func startReconnectLoop() {
        reconnectTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3s
                if !self.isConnected {
                    self.connect()
                }
            }
        }
    }
}
