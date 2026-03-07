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
    let option_labels: [String]?
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
    @Published var permissionOptions: [String] = []  // Human-readable option labels from service
    @Published var permissionRequestId: Int = 0  // Increments on each new request to ensure .onChange fires

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
            let isPending = (msg.status == "pending")
            permissionPending = isPending
            if isPending {
                permissionOptions = msg.option_labels ?? []
                permissionRequestId += 1  // Always increment so .onChange fires even if already pending
            }
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

    // MARK: - Send (widget → service)

    /// Send transcribed voice text to the service for tmux bridging to Claude Code.
    func sendVoiceInput(_ text: String) {
        let payload: [String: String] = ["command": "voice_input", "text": text]
        sendJSON(payload)
    }

    /// Send permission decision (from voice) to the service.
    /// - index: 0 = allow once, 1+ = apply suggestion at that 1-based index, -1 = deny
    func sendPermissionDecision(index: Int) {
        struct Payload: Encodable {
            let command: String
            let decision: String
            let suggestion_index: Int?
        }
        let payload = Payload(
            command: "permission_response",
            decision: index >= 0 ? "allow" : "deny",
            suggestion_index: index > 0 ? index : nil
        )
        guard let data = try? JSONEncoder().encode(payload),
              let text = String(data: data, encoding: .utf8) else { return }
        webSocketTask?.send(.string(text)) { error in
            if let error = error { print("[ws] Send error: \(error)") }
        }
        permissionPending = false
    }

    private func sendJSON(_ dict: [String: String]) {
        guard let data = try? JSONEncoder().encode(dict),
              let text = String(data: data, encoding: .utf8) else { return }
        webSocketTask?.send(.string(text)) { error in
            if let error = error {
                print("[ws] Send error: \(error)")
            }
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
