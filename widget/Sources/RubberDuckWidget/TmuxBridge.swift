// Tmux Bridge — Inject voice commands into Claude Code CLI via tmux send-keys.
//
// Uses Process to shell out to tmux. Only active in unsandboxed (dev) builds.

import Foundation

struct TmuxBridge {

    let session: String
    let pane: String

    init(session: String = DuckConfig.tmuxSession,
         pane: String = "\(DuckConfig.tmuxWindow).0") {
        self.session = session
        self.pane = pane
    }

    /// Send text to Claude Code via tmux send-keys.
    func sendToClaudeCode(_ text: String) {
        let target = "\(session):\(pane)"

        do {
            // Send the text literally (-l flag)
            let sendText = Process()
            sendText.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            sendText.arguments = ["tmux", "send-keys", "-t", target, "-l", text]
            sendText.standardOutput = FileHandle.nullDevice
            sendText.standardError = FileHandle.nullDevice
            try sendText.run()
            sendText.waitUntilExit()

            // Send Enter to execute
            let sendEnter = Process()
            sendEnter.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            sendEnter.arguments = ["tmux", "send-keys", "-t", target, "Enter"]
            sendEnter.standardOutput = FileHandle.nullDevice
            sendEnter.standardError = FileHandle.nullDevice
            try sendEnter.run()
            sendEnter.waitUntilExit()

            print("[tmux] Sent to \(target): \(String(text.prefix(80)))")
        } catch {
            print("[tmux] Failed to send: \(error)")
        }
    }
}
