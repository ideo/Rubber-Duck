// Eval Service — WebSocket connection to the Rubber Duck eval service.
// Receives evaluation scores and permission events.

import Foundation
import Combine

// MARK: - Data Models

struct EvalScores: Codable {
    let creativity: Double
    let soundness: Double
    let ambition: Double
    let elegance: Double
    let risk: Double
    let reaction: String?
}

struct EvalMessage: Codable {
    let type: String?
    let timestamp: String?
    let source: String?
    let text_preview: String?
    let scores: EvalScores?
    let status: String?
    let tool_name: String?
}

// MARK: - Service

@MainActor
class EvalService: ObservableObject {
    // Current state
    @Published var scores: EvalScores?
    @Published var reaction: String = ""
    @Published var source: String = ""
    @Published var isConnected: Bool = false

    // Permission state
    @Published var permissionPending: Bool = false
    @Published var permissionTool: String = ""

    // Computed expressions
    @Published var sentiment: Double = 0.0  // -1 to 1, overall mood

    private var webSocketTask: URLSessionWebSocketTask?
    private var reconnectTask: Task<Void, Never>?
    private let serviceURL = URL(string: "ws://localhost:3333/ws")!
    private let decoder = JSONDecoder()

    init() {
        connect()
    }

    deinit {
        reconnectTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }

    // MARK: - Connection

    func connect() {
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: serviceURL)
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

    // MARK: - Receive

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self.handleMessage(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.handleMessage(text)
                        }
                    @unknown default:
                        break
                    }
                    self.receiveMessage()

                case .failure:
                    self.isConnected = false
                }
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let msg = try? decoder.decode(EvalMessage.self, from: data) else {
            return
        }

        let msgType = msg.type ?? "eval"

        if msgType == "permission" {
            permissionTool = msg.tool_name ?? "unknown"
            permissionPending = (msg.status == "pending")
        } else if msgType == "eval", let newScores = msg.scores {
            scores = newScores
            reaction = newScores.reaction ?? ""
            source = msg.source ?? ""

            // Compute overall sentiment
            sentiment = (
                newScores.soundness * 0.3 +
                newScores.elegance * 0.25 +
                newScores.creativity * 0.2 +
                newScores.ambition * 0.15 -
                newScores.risk * 0.1
            )
        }
    }

    // MARK: - Reconnect

    private func startReconnectLoop() {
        reconnectTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                if !isConnected {
                    connect()
                }
            }
        }
    }
}
