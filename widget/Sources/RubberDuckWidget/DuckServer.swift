// Duck Server — Embedded HTTP + WebSocket server replacing the Python eval service.
//
// Replaces service/server.py + service/routes.py. Runs inside the widget app
// on port 3333. Hook scripts POST to the same endpoints as before — they
// don't know it's Swift now.
//
// Routes:
//   POST /evaluate    — receive hook payload, evaluate via Claude, broadcast + deliver locally
//   POST /permission  — receive hook payload, broadcast pending, wait for voice response
//   GET  /ws          — WebSocket for dashboard/viewer clients
//   GET  /            — serve dashboard.html
//   GET  /viewer      — serve viewer.html
//   GET  /health      — status JSON

import Foundation
import Hummingbird
import HummingbirdWebSocket
import HTTPTypes
import Logging
import NIOCore

@MainActor
class DuckServer: ObservableObject {
    @Published var isRunning = false

    let evaluator: ClaudeEvaluator
    let permissionGate: PermissionGate
    let broadcaster: WebSocketBroadcaster
    let tmuxBridge: TmuxBridge
    let localTransport: LocalEvalTransport

    private var serverTask: Task<Void, Never>?
    private let port: Int

    init(port: Int = DuckConfig.servicePort) {
        self.port = port
        self.evaluator = ClaudeEvaluator()
        self.permissionGate = PermissionGate()
        self.broadcaster = WebSocketBroadcaster()
        self.tmuxBridge = TmuxBridge()
        self.localTransport = LocalEvalTransport()

        // Wire local transport outbound → tmux bridge + permission gate
        localTransport.onVoiceInput = { [tmuxBridge] text in
            tmuxBridge.sendToClaudeCode(text)
        }
        localTransport.onPermissionResponse = { [permissionGate] decision, index in
            Task {
                await permissionGate.resolve(decision: decision, suggestionIndex: index)
            }
        }
    }

    // MARK: - Lifecycle

    func start() {
        guard serverTask == nil else { return }

        // Capture everything we need before leaving @MainActor
        let port = self.port
        let evaluator = self.evaluator
        let permissionGate = self.permissionGate
        let broadcaster = self.broadcaster
        let tmuxBridge = self.tmuxBridge
        let localTransport = self.localTransport

        let setRunning: @MainActor @Sendable (Bool) -> Void = { [weak self] value in
            self?.isRunning = value
        }

        serverTask = Task.detached {
            do {
                // Per-session memory: last Claude response, so user evals have context
                let sessionContext = SessionContext()

                // Build HTTP router
                let router = Router(context: BasicWebSocketRequestContext.self)

                // POST /evaluate
                router.post("/evaluate") { request, context -> Response in
                    let body = try await request.body.collect(upTo: 1_000_000)
                    guard let bodyData = body.getData(at: body.readerIndex, length: body.readableBytes),
                          let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
                        return Response(
                            status: .badRequest,
                            headers: [.contentType: "application/json"],
                            body: .init(byteBuffer: ByteBuffer(string: "{\"error\":\"invalid json\"}"))
                        )
                    }

                    let text = json["text"] as? String ?? ""
                    let source = json["source"] as? String ?? "unknown"
                    let userContext = json["user_context"] as? String ?? ""
                    let sessionId = json["session_id"] as? String ?? ""

                    guard !text.isEmpty else {
                        return Response(
                            status: .badRequest,
                            headers: [.contentType: "application/json"],
                            body: .init(byteBuffer: ByteBuffer(string: "{\"error\":\"no text\"}"))
                        )
                    }

                    // Track context: store Claude's response, recall for user evals
                    var claudeContext = ""
                    if source == "claude" {
                        sessionContext.store(sessionId: sessionId, text: text)
                    } else if source == "user" {
                        claudeContext = sessionContext.recall(sessionId: sessionId)
                    }

                    // Evaluate via Claude
                    let scores: EvalScores
                    do {
                        scores = try await evaluator.evaluate(text: text, source: source, userContext: userContext, claudeContext: claudeContext)
                    } catch {
                        DuckLog.log("[server] Eval error: \(error)")
                        scores = EvalScores(
                            creativity: 0, soundness: 0, ambition: 0,
                            elegance: 0, risk: 0,
                            reaction: "I'm confused",
                            summary: "Evaluation failed"
                        )
                    }

                    let textPreview = String(text.prefix(150)) + (text.count > 150 ? "..." : "")
                    let timestamp = ISO8601DateFormatter().string(from: Date())

                    let result = EvalResult(
                        type: "eval",
                        timestamp: timestamp,
                        source: source,
                        textPreview: textPreview,
                        sessionId: sessionId,
                        scores: scores
                    )

                    // Broadcast to WebSocket clients (dashboard, viewer)
                    await broadcaster.broadcast(result)

                    // Deliver locally to widget UI
                    await MainActor.run {
                        localTransport.deliver(result)
                    }

                    // Log
                    DuckLog.log("[\(source)] \(scores.reaction ?? "...")  |  \(scores.summary ?? "")  |  "
                        + "cr:\(String(format: "%+.1f", scores.creativity)) "
                        + "sn:\(String(format: "%+.1f", scores.soundness)) "
                        + "am:\(String(format: "%+.1f", scores.ambition)) "
                        + "el:\(String(format: "%+.1f", scores.elegance)) "
                        + "ri:\(String(format: "%+.1f", scores.risk))")

                    // Return JSON response
                    let responseData = try JSONEncoder().encode(result)
                    return Response(
                        status: .ok,
                        headers: [.contentType: "application/json"],
                        body: .init(byteBuffer: ByteBuffer(data: responseData))
                    )
                }

                // POST /permission
                router.post("/permission") { request, context -> Response in
                    let body = try await request.body.collect(upTo: 100_000)
                    guard let bodyData = body.getData(at: body.readerIndex, length: body.readableBytes),
                          let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
                        return Response(
                            status: .badRequest,
                            headers: [.contentType: "application/json"],
                            body: .init(byteBuffer: ByteBuffer(string: "{\"error\":\"invalid json\"}"))
                        )
                    }

                    let toolName = json["tool_name"] as? String ?? "unknown"
                    let toolInput = json["tool_input"] ?? "{}"
                    let suggestions = json["permission_suggestions"] as? [[String: Any]] ?? []

                    let optionLabels = suggestions.map { PermissionGate.describeSuggestion($0) }

                    DuckLog.log("[permission] Request: \(toolName) (\(suggestions.count) options)")

                    // Broadcast pending to WebSocket clients
                    let pendingEvent = PermissionEvent(
                        type: "permission",
                        status: "pending",
                        toolName: toolName,
                        toolInput: String(describing: toolInput).prefix(200).description,
                        optionLabels: optionLabels
                    )
                    await broadcaster.broadcast(pendingEvent)

                    // Deliver locally so widget can voice-ask
                    await MainActor.run {
                        localTransport.deliverPermission(pendingEvent)
                    }

                    // Wait for voice response
                    let (decision, suggestionIndex) = await permissionGate.waitForDecision()

                    if decision == "timeout" {
                        DuckLog.log("[permission] Timeout — no response")
                        let timeoutEvent = PermissionEvent(
                            type: "permission", status: "timeout",
                            toolName: toolName, toolInput: nil, optionLabels: nil
                        )
                        await broadcaster.broadcast(timeoutEvent)
                        await MainActor.run {
                            localTransport.deliverPermission(timeoutEvent)
                        }
                        return Response(
                            status: .ok,
                            headers: [.contentType: "application/json"],
                            body: .init(byteBuffer: ByteBuffer(string: "{}"))
                        )
                    }

                    // Broadcast resolution
                    let resolvedEvent = PermissionEvent(
                        type: "permission", status: decision,
                        toolName: toolName, toolInput: nil, optionLabels: nil
                    )
                    await broadcaster.broadcast(resolvedEvent)
                    await MainActor.run {
                        localTransport.deliverPermission(resolvedEvent)
                    }

                    // Build response
                    var responseDict: [String: Any] = ["decision": decision]
                    if decision == "allow", let idx = suggestionIndex {
                        responseDict["suggestion_index"] = idx
                    }
                    let responseData = try JSONSerialization.data(withJSONObject: responseDict)
                    return Response(
                        status: .ok,
                        headers: [.contentType: "application/json"],
                        body: .init(byteBuffer: ByteBuffer(data: responseData))
                    )
                }

                // GET /health
                router.get("/health") { request, context -> Response in
                    let clientCount = await broadcaster.clientCount
                    let healthDict: [String: Any] = [
                        "status": "ok",
                        "connected_clients": clientCount,
                        "dimensions": ["creativity", "soundness", "ambition", "elegance", "risk"],
                        "server": "swift",
                        "tmux_target": "\(DuckConfig.tmuxSession):\(DuckConfig.tmuxWindow).0",
                    ]
                    let data = try JSONSerialization.data(withJSONObject: healthDict)
                    return Response(
                        status: .ok,
                        headers: [.contentType: "application/json"],
                        body: .init(byteBuffer: ByteBuffer(data: data))
                    )
                }

                // GET / — dashboard
                router.get("/") { request, context -> Response in
                    guard let url = Bundle.module.url(forResource: "dashboard", withExtension: "html"),
                          let html = try? String(contentsOf: url, encoding: .utf8) else {
                        return Response(status: .notFound)
                    }
                    return Response(
                        status: .ok,
                        headers: [.contentType: "text/html; charset=utf-8"],
                        body: .init(byteBuffer: ByteBuffer(string: html))
                    )
                }

                // GET /viewer — 3D viewer
                router.get("/viewer") { request, context -> Response in
                    guard let url = Bundle.module.url(forResource: "viewer", withExtension: "html"),
                          let html = try? String(contentsOf: url, encoding: .utf8) else {
                        return Response(status: .notFound)
                    }
                    return Response(
                        status: .ok,
                        headers: [.contentType: "text/html; charset=utf-8"],
                        body: .init(byteBuffer: ByteBuffer(string: html))
                    )
                }

                // WebSocket /ws
                router.ws("/ws") { request, context in
                    .upgrade([:])
                } onUpgrade: { inbound, outbound, context in
                    let connectionId = await broadcaster.add(outbound)

                    do {
                        for try await message in inbound.messages(maxSize: 1 << 16) {
                            switch message {
                            case .text(let text):
                                guard let data = text.data(using: .utf8),
                                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                      let command = json["command"] as? String else {
                                    continue
                                }

                                switch command {
                                case "voice_input":
                                    if let inputText = json["text"] as? String, !inputText.trimmingCharacters(in: .whitespaces).isEmpty {
                                        tmuxBridge.sendToClaudeCode(inputText.trimmingCharacters(in: .whitespaces))
                                    }
                                case "permission_response":
                                    let decision = json["decision"] as? String ?? "deny"
                                    let suggestionIndex = json["suggestion_index"] as? Int
                                    await permissionGate.resolve(decision: decision, suggestionIndex: suggestionIndex)
                                default:
                                    break
                                }

                            case .binary:
                                break  // Ignore binary messages
                            }
                        }
                    } catch {
                        // Client disconnected
                    }

                    await broadcaster.remove(connectionId)
                }

                // Build and run the application
                var logger = Logger(label: "duck-server")
                logger.logLevel = .info

                let app = Application(
                    router: router,
                    server: .http1WebSocketUpgrade(
                        webSocketRouter: router,
                        configuration: .init(autoPing: .disabled)
                    ),
                    configuration: .init(
                        address: .hostname("127.0.0.1", port: port),
                        serverName: "RubberDuck"
                    ),
                    logger: logger
                )

                DuckLog.log("[server] Started on http://localhost:\(port)")

                await setRunning(true)

                try await app.run()

            } catch {
                DuckLog.log("[server] Failed to start: \(error)")
                await setRunning(false)
            }
        }
    }

    func stop() {
        serverTask?.cancel()
        serverTask = nil
        isRunning = false
        DuckLog.log("[server] Stopped")
    }
}

// MARK: - Session Context (thread-safe per-session memory)

/// Stores last Claude response per session so user evals have context.
private final class SessionContext: @unchecked Sendable {
    private var lock = NSLock()
    private var lastClaudeText: [String: String] = [:]

    func store(sessionId: String, text: String) {
        lock.lock()
        lastClaudeText[sessionId] = text
        lock.unlock()
    }

    func recall(sessionId: String) -> String {
        lock.lock()
        defer { lock.unlock() }
        return lastClaudeText[sessionId] ?? ""
    }
}

// MARK: - Helpers

private extension String {
    static func * (lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}
