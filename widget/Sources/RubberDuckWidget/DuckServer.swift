// Duck Server — Embedded HTTP + WebSocket server for eval, permissions, and dashboard.
//
// Runs inside the widget app on port 3333. Hook scripts POST eval payloads
// and permission requests. Dispatches to LocalEvaluator (Foundation Models)
// or ClaudeEvaluator (Anthropic API) based on DuckConfig.evalProvider.
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
    /// True after a Claude Code session has pinged /health (SessionStart hook).
    @Published var pluginConnected = false

    /// Called when a new session connects via /health. Wired to TTS greeting by the app.
    var onSessionConnect: (() -> Void)?

    let claudeEvaluator: ClaudeEvaluator
    let geminiEvaluator: GeminiEvaluator
    let localEvaluator: LocalEvaluator
    let permissionGate: PermissionGate
    let broadcaster: WebSocketBroadcaster
    let tmuxBridge: TmuxBridge
    let localTransport: LocalEvalTransport

    /// True when Foundation Models is available on this device.
    let foundationModelsAvailable: Bool

    private var server: MiniServer?
    private let port: Int

    init(port: Int = DuckConfig.servicePort) {
        self.port = port
        self.claudeEvaluator = ClaudeEvaluator()
        self.geminiEvaluator = GeminiEvaluator()
        self.localEvaluator = LocalEvaluator()
        self.foundationModelsAvailable = LocalEvaluator.isAvailable
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
        let claudeEvaluator = self.claudeEvaluator
        let geminiEvaluator = self.geminiEvaluator
        let localEvaluator = self.localEvaluator
        let permissionGate = self.permissionGate
        let broadcaster = self.broadcaster
        let tmuxBridge = self.tmuxBridge
        let localTransport = self.localTransport
        let port = self.port
        let markPluginConnected: @Sendable () async -> Void = {
            await MainActor.run {
                let wasConnected = self.pluginConnected
                self.pluginConnected = true
                if !wasConnected {
                    self.onSessionConnect?()
                }
            }
        }

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
            let wildcardOn = DuckVoices.isWildcardPersisted
            do {
                switch DuckConfig.evalProvider {
                case .foundation:
                    scores = try await localEvaluator.evaluate(text: text, source: source,
                                                                userContext: userContext,
                                                                claudeContext: claudeContext,
                                                                wildcardEnabled: wildcardOn)
                case .anthropic:
                    scores = try await claudeEvaluator.evaluate(text: text, source: source,
                                                                 userContext: userContext,
                                                                 claudeContext: claudeContext,
                                                                 wildcardEnabled: wildcardOn)
                case .gemini:
                    scores = try await geminiEvaluator.evaluate(text: text, source: source,
                                                                userContext: userContext,
                                                                claudeContext: claudeContext,
                                                                wildcardEnabled: wildcardOn)
                }
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

        #if DEBUG
        // POST /demo — inject a canned eval result (bypasses evaluator).
        // Used for recording demos with deterministic reactions.
        // Body: { "source": "user|claude", "text_preview": "...", "scores": { ... } }
        srv.post("/demo") { request in
            guard let json = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any],
                  let scoresDict = json["scores"] as? [String: Any] else {
                return .badRequest("need {source, text_preview, scores: {creativity,soundness,ambition,elegance,risk,reaction,summary}}")
            }

            let source = json["source"] as? String ?? "claude"
            let textPreview = json["text_preview"] as? String ?? ""
            let scores = EvalScores(
                creativity: scoresDict["creativity"] as? Double ?? 0,
                soundness: scoresDict["soundness"] as? Double ?? 0,
                ambition: scoresDict["ambition"] as? Double ?? 0,
                elegance: scoresDict["elegance"] as? Double ?? 0,
                risk: scoresDict["risk"] as? Double ?? 0,
                reaction: scoresDict["reaction"] as? String,
                summary: scoresDict["summary"] as? String
            )

            let timestamp = ISO8601DateFormatter().string(from: Date())
            let result = EvalResult(
                type: "eval",
                timestamp: timestamp,
                source: source,
                textPreview: textPreview,
                sessionId: "demo",
                scores: scores
            )

            await broadcaster.broadcast(result)
            await MainActor.run { localTransport.deliver(result) }

            DuckLog.log("[demo] \(scores.reaction ?? "...")  |  \(scores.summary ?? "")")

            guard let responseData = try? JSONEncoder().encode(result) else {
                return .badRequest("encode error")
            }
            return .json(responseData)
        }
        #endif

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

        // POST /permission-gemini — notification-only alert
        // Gemini's Notification hook is observe-only (can't relay decisions back),
        // so we just speak an alert and let the user handle it in the terminal.
        srv.post("/permission-gemini") { request in
            guard let json = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any] else {
                return .badRequest("invalid json")
            }

            let toolName = json["tool_name"] as? String ?? ""
            DuckLog.log("[permission-gemini] Alert: \(toolName)")

            // Speak a brief heads-up — user handles approval in the terminal
            let alert = "Hey! Gemini needs your permission."
            await MainActor.run {
                localTransport.deliverPermission(PermissionEvent(
                    type: "permission",
                    status: "pending",
                    toolName: toolName,
                    toolInput: nil,
                    optionLabels: nil,
                    actionSummary: alert
                ))
            }
            await broadcaster.broadcast(PermissionEvent(
                type: "permission",
                status: "pending",
                toolName: toolName,
                toolInput: nil,
                optionLabels: nil,
                actionSummary: alert
            ))

            return .json("{\"status\":\"received\"}".data(using: .utf8)!)
        }

        // POST /session-end — Claude Code session terminated
        srv.post("/session-end") { [localTransport] request in
            let json = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any]
            let reason = json?["reason"] as? String ?? "unknown"
            DuckLog.log("[session-end] reason=\(reason)")

            let goodbyes: [String] = switch reason {
            case "prompt_input_exit":
                ["Later!", "See ya.", "Peace out.", "Catch you next time.", "Till next time."]
            case "clear":
                ["Fresh start. Nice.", "Clean slate.", "Wiped clean."]
            default:
                ["Session over.", "Done for now.", "Signing off."]
            }

            await MainActor.run {
                localTransport.onClearThinking?()
                localTransport.onSpeak?(goodbyes.randomElement()!)
            }
            return .json("{\"status\":\"ok\"}".data(using: .utf8)!)
        }

        // POST /stop-failure — API error (rate limit, auth, server error, etc.)
        srv.post("/stop-failure") { [localTransport] request in
            let json = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any]
            let errorType = json?["error_type"] as? String ?? "unknown"
            DuckLog.log("[stop-failure] error_type=\(errorType)")

            let reaction: String = switch errorType {
            case "rate_limit":
                ["Hit the rate limit. Take a breather.", "Throttled. Slow down.", "Rate limited. Wait a sec."].randomElement()!
            case "authentication_failed":
                ["Auth failed. Check your API key.", "Credentials expired."].randomElement()!
            case "billing_error":
                ["Billing issue. Check your account.", "Payment problem."].randomElement()!
            case "server_error":
                ["Server's down. Not our fault.", "Server error. Try again.", "Their end, not ours."].randomElement()!
            case "max_output_tokens":
                ["Hit the output limit. Response was too long.", "Ran out of tokens."].randomElement()!
            default:
                ["Something went wrong.", "Hit a snag.", "Error. Not sure what."].randomElement()!
            }

            await MainActor.run {
                localTransport.onClearThinking?()
                localTransport.onSpeak?(reaction)
            }
            return .json("{\"status\":\"ok\"}".data(using: .utf8)!)
        }

        // POST /compact — context window compaction (pre/post)
        srv.post("/compact") { [localTransport] request in
            let json = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any]
            let phase = json?["phase"] as? String ?? "pre"
            let trigger = json?["trigger"] as? String ?? "auto"
            DuckLog.log("[compact] phase=\(phase) trigger=\(trigger)")

            await MainActor.run {
                if phase == "pre" {
                    localTransport.onMelodyStart?()
                } else {
                    localTransport.onMelodyStop?()
                }
            }
            return .json("{\"status\":\"ok\"}".data(using: .utf8)!)
        }

        // POST /permission-clear — tool succeeded, permission is resolved
        // Signal from PostToolUse hook — user approved via CLI (not voice).
        // Resolves the PermissionGate so the original /permission curl unblocks,
        // clears the voice gate, and updates the UI.
        srv.post("/permission-clear") { [permissionGate, localTransport] _ in
            DuckLog.log("[permission] CLI approval — tool succeeded, clearing permission state")
            // Resolve the gate so /permission's blocked curl returns
            await permissionGate.resolve(decision: "allow")
            await MainActor.run {
                localTransport.onClearThinking?()
            }
            let resolved = PermissionEvent(
                type: "permission",
                status: "allow",
                toolName: "",
                toolInput: nil,
                optionLabels: nil,
                actionSummary: nil
            )
            await MainActor.run { localTransport.deliverPermission(resolved) }
            await broadcaster.broadcast(resolved)
            return .json("{\"status\":\"ok\"}".data(using: .utf8)!)
        }

        // GET /health
        srv.get("/health") { _ in
            await markPluginConnected()
            let clientCount = await broadcaster.clientCount
            let healthDict: [String: Any] = [
                "status": "ok",
                "connected_clients": clientCount,
                "dimensions": ["creativity", "soundness", "ambition", "elegance", "risk"],
                "server": "swift",
                "eval_provider": DuckConfig.evalProvider.rawValue,
                "tmux_target": "\(DuckConfig.tmuxSession):\(DuckConfig.tmuxWindow).0",
            ]
            return .json(healthDict)
        }

        // GET / — dashboard
        srv.get("/") { _ in
            guard let url = Resources.bundle.url(forResource: "dashboard", withExtension: "html"),
                  let html = try? String(contentsOf: url, encoding: .utf8) else {
                return .notFound
            }
            return .html(html)
        }

        // GET /viewer — 3D viewer
        srv.get("/viewer") { _ in
            guard let url = Resources.bundle.url(forResource: "viewer", withExtension: "html"),
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
        // Claude Code provides a description field — use it directly when available
        if let desc = dict["description"] as? String, !desc.isEmpty {
            // Cap at ~8 words for TTS
            let words = desc.components(separatedBy: .whitespaces)
            let truncated = words.prefix(8).joined(separator: " ")
            return truncated
        }
        guard let command = dict["command"] as? String else { return "Run a command" }
        return summarizeBashCommand(command)

    case "Edit":
        if let path = dict["file_path"] as? String {
            return "Edit \(fileLabel(path))"
        }
        return "Edit a file"

    case "Write":
        if let path = dict["file_path"] as? String {
            return "Write \(fileLabel(path))"
        }
        return "Write a new file"

    case "WebFetch":
        return "Fetch a webpage"

    case "Glob", "Grep":
        return "Search the codebase"

    case "Read":
        if let path = dict["file_path"] as? String {
            return "Read \(fileLabel(path))"
        }
        return "Read a file"

    // Claude Code internal tools — still require voice confirmation, but friendlier prompts
    case "ExitPlanMode":
        return "Claude wants to exit plan mode"
    case "EnterPlanMode":
        return "Claude wants to enter plan mode"
    case "AskUserQuestion":
        return "Claude has a question"
    case "TodoWrite":
        return "Claude wants to update tasks"
    case "NotebookEdit":
        return "Edit a notebook"
    case "Agent":
        return "Claude wants to launch a sub-agent"

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

/// Extract a short, speakable label from a file path (e.g. "DuckView" from ".../DuckView.swift").
private func fileLabel(_ path: String) -> String {
    let basename = (path as NSString).lastPathComponent
    return (basename as NSString).deletingPathExtension
}

/// Parse a Bash command string to extract the first meaningful command for TTS.
/// Skips cd, source, export, and chains (&&, ||, ;) to find the real action.
private func summarizeBashCommand(_ command: String) -> String {
    // Split on shell operators to find meaningful commands
    let segments = command
        .replacingOccurrences(of: "&&", with: "\n")
        .replacingOccurrences(of: "||", with: "\n")
        .replacingOccurrences(of: ";", with: "\n")
        .components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }

    // Find the first non-trivial command (skip cd, source, export, set, eval)
    let trivial: Set<String> = ["cd", "source", "export", "set", "eval", "pushd", "popd", "shopt", "setopt", "unset"]
    let meaningful = segments.first { line in
        let base = line.components(separatedBy: .whitespaces).first ?? ""
        return !trivial.contains(base)
    } ?? segments.last ?? command

    let words = meaningful.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
    let base = words.first ?? ""

    switch base {
    case "git":
        let sub = words.count > 1 ? words[1] : ""
        return sub.isEmpty ? "Run git" : "Run git \(sub)"
    case "npm", "npx":
        let sub = words.count > 1 ? words[1] : ""
        return sub.isEmpty ? "Run \(base)" : "Run \(base) \(sub)"
    case "make":
        let target = words.count > 1 && !words[1].hasPrefix("-") ? words[1] : ""
        return target.isEmpty ? "Run make" : "Run make \(target)"
    case "swift":
        let sub = words.count > 1 ? words[1] : ""
        return sub.isEmpty ? "Run swift" : "Run swift \(sub)"
    case "curl", "wget": return "Make a network request"
    case "rm":      return "Delete files"
    case "mkdir":   return "Create a directory"
    case "pip", "pip3", "brew", "cargo", "yarn", "pnpm", "bun":
        let sub = words.count > 1 ? words[1] : ""
        return sub.isEmpty ? "Run \(base)" : "Run \(base) \(sub)"
    case "ls", "find", "tree": return "List files"
    case "cat", "head", "tail", "less": return "Read a file"
    case "cp", "mv": return "Move files"
    case "chmod", "chown": return "Change file permissions"
    case "docker":
        let sub = words.count > 1 ? words[1] : ""
        return sub.isEmpty ? "Run docker" : "Run docker \(sub)"
    case "xcodebuild": return "Build with Xcode"
    case "kill", "killall", "pkill": return "Stop a process"
    case "echo":    return "Run a command"
    default:        return "Run a command"
    }
}

