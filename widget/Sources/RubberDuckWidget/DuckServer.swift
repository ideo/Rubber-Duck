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

@MainActor
class DuckServer: ObservableObject {
    @Published var isRunning = false

    let evaluator: ClaudeEvaluator
    let permissionGate: PermissionGate
    let broadcaster: WebSocketBroadcaster
    let tmuxBridge: TmuxBridge
    let localTransport: LocalEvalTransport

    private var server: MiniServer?
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
        guard server == nil else { return }

        // Capture service references for route handler closures
        let evaluator = self.evaluator
        let permissionGate = self.permissionGate
        let broadcaster = self.broadcaster
        let tmuxBridge = self.tmuxBridge
        let localTransport = self.localTransport
        let port = self.port

        let srv = MiniServer(port: UInt16(port))

        // Per-session memory: last Claude response, so user evals have context
        let sessionContext = SessionContext()

        // Shared evaluation logic for /evaluate and /hook/* endpoints
        let runEval: @Sendable (_ text: String, _ source: String, _ userContext: String, _ sessionId: String) async -> HTTPResponse = { text, source, userContext, sessionId in
            guard !text.isEmpty else {
                return .badRequest("no text")
            }

            // Track context: store Claude's response, recall for user evals
            var claudeContext = ""
            if source == "claude" {
                sessionContext.store(sessionId: sessionId, text: text)
            } else if source == "user" {
                claudeContext = sessionContext.recall(sessionId: sessionId)
            }

            let scores: EvalScores
            do {
                scores = try await evaluator.evaluate(text: text, source: source,
                                                       userContext: userContext,
                                                       claudeContext: claudeContext)
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

            await broadcaster.broadcast(result)
            await MainActor.run { localTransport.deliver(result) }

            DuckLog.log("[\(source)] \(scores.reaction ?? "...")  |  \(scores.summary ?? "")  |  "
                + "cr:\(String(format: "%+.1f", scores.creativity)) "
                + "sn:\(String(format: "%+.1f", scores.soundness)) "
                + "am:\(String(format: "%+.1f", scores.ambition)) "
                + "el:\(String(format: "%+.1f", scores.elegance)) "
                + "ri:\(String(format: "%+.1f", scores.risk))")

            guard let responseData = try? JSONEncoder().encode(result) else {
                return .badRequest("encode error")
            }
            return .json(responseData)
        }

        // POST /evaluate (legacy — used by shell hook scripts and dashboard)
        srv.post("/evaluate") { request in
            guard let json = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any] else {
                return .badRequest("invalid json")
            }
            let text = json["text"] as? String ?? ""
            let source = json["source"] as? String ?? "unknown"
            let userContext = json["user_context"] as? String ?? ""
            let sessionId = json["session_id"] as? String ?? ""
            return await runEval(text, source, userContext, sessionId)
        }

        // POST /permission
        srv.post("/permission") { request in
            guard let json = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any] else {
                return .badRequest("invalid json")
            }

            let toolName = json["tool_name"] as? String ?? "unknown"
            let toolInput = json["tool_input"] ?? "{}"
            let suggestions = json["permission_suggestions"] as? [[String: Any]] ?? []

            let optionLabels = suggestions.map { PermissionGate.describeSuggestion($0) }
            let summary = summarizePermission(toolName: toolName, toolInput: toolInput)

            DuckLog.log("[permission] Request: \(toolName) → \"\(summary)\" (\(suggestions.count) options)")

            // Broadcast pending to WebSocket clients
            let pendingEvent = PermissionEvent(
                type: "permission",
                status: "pending",
                toolName: toolName,
                toolInput: String(describing: toolInput).prefix(200).description,
                optionLabels: optionLabels,
                actionSummary: summary
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
                    toolName: toolName, toolInput: nil, optionLabels: nil, actionSummary: nil
                )
                await broadcaster.broadcast(timeoutEvent)
                await MainActor.run {
                    localTransport.deliverPermission(timeoutEvent)
                }
                return .json("{}".data(using: .utf8)!)
            }

            // Broadcast resolution
            let resolvedEvent = PermissionEvent(
                type: "permission", status: decision,
                toolName: toolName, toolInput: nil, optionLabels: nil, actionSummary: nil
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
            guard let responseData = try? JSONSerialization.data(withJSONObject: responseDict) else {
                return .badRequest("encode error")
            }
            return .json(responseData)
        }

        // GET /health
        srv.get("/health") { _ in
            let clientCount = await broadcaster.clientCount
            let healthDict: [String: Any] = [
                "status": "ok",
                "connected_clients": clientCount,
                "dimensions": ["creativity", "soundness", "ambition", "elegance", "risk"],
                "server": "swift",
                "tmux_target": "\(DuckConfig.tmuxSession):\(DuckConfig.tmuxWindow).0",
            ]
            return .json(healthDict)
        }

        // GET / — dashboard
        srv.get("/") { _ in
            guard let url = Bundle.module.url(forResource: "dashboard", withExtension: "html"),
                  let html = try? String(contentsOf: url, encoding: .utf8) else {
                return .notFound
            }
            return .html(html)
        }

        // GET /viewer — 3D viewer
        srv.get("/viewer") { _ in
            guard let url = Bundle.module.url(forResource: "viewer", withExtension: "html"),
                  let html = try? String(contentsOf: url, encoding: .utf8) else {
                return .notFound
            }
            return .html(html)
        }

        // WebSocket /ws
        srv.websocket("/ws",
            onConnect: { ws in
                Task { await broadcaster.add(ws) }
            },
            onMessage: { ws, text in
                guard let data = text.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let command = json["command"] as? String else {
                    return
                }

                switch command {
                case "voice_input":
                    if let inputText = json["text"] as? String,
                       !inputText.trimmingCharacters(in: .whitespaces).isEmpty {
                        tmuxBridge.sendToClaudeCode(inputText.trimmingCharacters(in: .whitespaces))
                    }
                case "permission_response":
                    let decision = json["decision"] as? String ?? "deny"
                    let suggestionIndex = json["suggestion_index"] as? Int
                    await permissionGate.resolve(decision: decision, suggestionIndex: suggestionIndex)
                default:
                    break
                }
            },
            onDisconnect: { ws in
                Task { await broadcaster.remove(ws.id) }
            }
        )

        // Start the server
        do {
            try srv.start()
            server = srv
            isRunning = true
            DuckLog.log("[server] Started on http://localhost:\(port)")
        } catch {
            DuckLog.log("[server] Failed to start: \(error)")
        }
    }

    func stop() {
        server?.stop()
        server = nil
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

// MARK: - Permission Summarization

/// Generate a short, TTS-friendly description of what a tool wants to do.
/// Never reads raw commands, paths, or URLs aloud — always human speech.
func summarizePermission(toolName: String, toolInput: Any) -> String {
    // Try to parse toolInput as a JSON dict (it may arrive as a string or dict)
    let dict: [String: Any]
    if let d = toolInput as? [String: Any] {
        dict = d
    } else if let str = toolInput as? String,
              let data = str.data(using: .utf8),
              let d = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        dict = d
    } else {
        dict = [:]
    }

    switch toolName {
    case "Bash":
        guard let command = dict["command"] as? String else { return "Run a command" }
        let base = command.trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespaces).first ?? ""
        switch base {
        case "git":     return "Run git"
        case "npm", "npx": return "Run \(base)"
        case "make":    return "Run make"
        case "swift":   return "Run swift"
        case "curl", "wget": return "Make a network request"
        case "rm":      return "Delete files"
        case "mkdir":   return "Create a directory"
        case "pip", "pip3", "brew", "cargo", "yarn", "pnpm", "bun":
            return "Run \(base)"
        case "ls", "find", "tree": return "List files"
        case "cat", "head", "tail", "less": return "Read a file"
        case "cd":      return "Change directory"
        case "cp", "mv": return "Move files"
        case "chmod", "chown": return "Change file permissions"
        case "docker":  return "Run docker"
        case "xcodebuild": return "Build with Xcode"
        default:        return "Run a command"
        }

    case "Edit":
        if let path = dict["file_path"] as? String {
            let basename = (path as NSString).lastPathComponent
            let name = (basename as NSString).deletingPathExtension
            return "Edit \(name)"
        }
        return "Edit a file"

    case "Write":
        return "Write a new file"

    case "WebFetch":
        return "Fetch a webpage"

    case "Glob", "Grep":
        return "Search the codebase"

    case "Read":
        if let path = dict["file_path"] as? String {
            let basename = (path as NSString).lastPathComponent
            let name = (basename as NSString).deletingPathExtension
            return "Read \(name)"
        }
        return "Read a file"

    default:
        // MCP tools: mcp__server-name__tool_name → "Use a connector"
        if toolName.hasPrefix("mcp__") {
            return "Use a connector"
        }
        // Any other unknown tool with underscores → generic fallback
        if toolName.contains("_") {
            return "Use a tool"
        }
        return toolName
    }
}

