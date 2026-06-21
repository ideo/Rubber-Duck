// Cursor Installer — one-click wiring of the duck's hooks into Cursor (1.7+).
//
// Cursor gained an agent-lifecycle hooks system in 1.7. Unlike Claude Code
// (which we reach via a marketplace plugin), Cursor reads a plain JSON config
// at ~/.cursor/hooks.json that points at executable scripts. So "installing"
// for Cursor means:
//   1. Copy the bundled cursor/hooks/* adapter scripts to a stable location
//      (Application Support — survives app updates, lives outside the .app).
//   2. Merge our four hook entries into ~/.cursor/hooks.json with ABSOLUTE
//      paths, preserving any hooks the user already configured.
//   3. Tell the user to reload Cursor.
//
// The adapter scripts translate Cursor's hook JSON shapes into the same
// /evaluate and /permission calls the Claude Code hooks make, so the widget's
// server is untouched and the two editors can run side by side.
//
// No sandbox: this build is GitHub-release only (see project memory / CLAUDE.md),
// so writing ~/.cursor/hooks.json directly is allowed — that's the whole reason
// the one-click flow is possible.

import AppKit

enum CursorInstaller {
    /// Callback for voice feedback during install. Set by the app on launch
    /// (mirrors PluginInstaller.onSpeak).
    @MainActor static var onSpeak: ((String) -> Void)?

    /// Where the adapter scripts get copied to. Deliberately a SPACE-FREE path
    /// under the home dir — NOT Application Support. Cursor runs each hook's
    /// `command` through `zsh`, and a space in the path ("Application Support")
    /// breaks the command (exit 127: "no such file or directory: …/Library/Application").
    /// A path with no spaces is safe no matter how Cursor spawns the process.
    private static var installedHooksDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".duck-duck-duck/cursor-hooks")
    }

    /// ~/.cursor/hooks.json — Cursor's user-global hook config.
    private static var cursorConfigURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cursor/hooks.json")
    }

    // The hooks we own, and which adapter script backs each. One script
    // (on-permission.sh) serves both permission events.
    private static let hookScripts: [(event: String, script: String)] = [
        ("beforeSubmitPrompt", "on-before-submit-prompt.sh"),
        ("afterAgentResponse", "on-after-agent-response.sh"),
        ("beforeShellExecution", "on-permission.sh"),
        ("beforeMCPExecution", "on-permission.sh"),
        ("afterShellExecution", "on-after-shell.sh"),
    ]

    /// Recognize our own hook entries by script filename rather than by install
    /// directory. This survives the install path changing (e.g. the move off
    /// Application Support) — old entries from a prior path are still matched,
    /// so re-Connect cleanly replaces them instead of stacking duplicates.
    private static func isOurCommand(_ command: String) -> Bool {
        let names = Set(hookScripts.map(\.script))
        return names.contains { command.hasSuffix("/\($0)") || command == $0 }
    }

    // MARK: - Detection

    /// Is Cursor installed? Checks Launch Services by bundle id (works even if
    /// never launched), then falls back to the common app locations.
    static func isCursorInstalled() -> Bool {
        // Cursor ships under a ToDesktop bundle id.
        if let urls = LSCopyApplicationURLsForBundleIdentifier(
            "com.todesktop.230313mzl4w4u92" as CFString, nil
        )?.takeRetainedValue() as? [URL], !urls.isEmpty {
            return true
        }
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        for path in ["/Applications/Cursor.app", "\(home)/Applications/Cursor.app"] {
            if fm.fileExists(atPath: path) { return true }
        }
        // ~/.cursor exists once Cursor has run at least once.
        return fm.fileExists(atPath: "\(home)/.cursor")
    }

    /// Are our hooks already wired into ~/.cursor/hooks.json?
    ///
    /// We PARSE the JSON rather than substring-matching the raw file: JSONSerialization
    /// escapes "/" as "\/" on write, so a raw `.contains` on the on-disk text would miss.
    /// Parsed command strings are unescaped, so matching our script names works.
    static func areHooksInstalled() -> Bool {
        guard let data = try? Data(contentsOf: cursorConfigURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = root["hooks"] as? [String: Any] else {
            return false
        }
        for (_, value) in hooks {
            guard let entries = value as? [[String: Any]] else { continue }
            for entry in entries {
                if let cmd = entry["command"] as? String, isOurCommand(cmd) {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Install

    /// Entry point for the menu / spoken offer. Copies scripts, merges config,
    /// then guides the user to reload Cursor.
    @MainActor
    static func install() {
        guard isCursorInstalled() else {
            onSpeak?("I don't see Cursor on this Mac.")
            showResult(success: false,
                       detail: "Cursor doesn't appear to be installed. Install Cursor 1.7 or newer, then try again.")
            return
        }
        onSpeak?("Wiring myself into Cursor. One sec.")
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let dir = try copyBundledScripts()
                try mergeConfig(hooksDir: dir)
                Task { @MainActor in
                    onSpeak?("Done. Reload Cursor and I'll be watching.")
                    showResult(success: true, detail: """
                        Hooks installed for Cursor.

                        Reload Cursor to activate them:
                        Cmd+Shift+P → “Reload Window”.
                        """)
                }
            } catch {
                DuckLog.log("[cursor] install failed: \(error)")
                Task { @MainActor in
                    onSpeak?("Something went wrong wiring up Cursor.")
                    showResult(success: false, detail: "Install failed:\n\(error.localizedDescription)")
                }
            }
        }
    }

    /// Copy the bundled cursor/hooks folder into Application Support and make
    /// the scripts executable. Returns the destination directory.
    private static func copyBundledScripts() throws -> URL {
        guard let bundled = findBundledHooks() else {
            throw CursorError.bundledHooksMissing
        }
        let fm = FileManager.default
        let dest = installedHooksDir

        // Replace any prior copy so updates land cleanly.
        try? fm.removeItem(at: dest)
        try fm.createDirectory(at: dest, withIntermediateDirectories: true)

        for item in try fm.contentsOfDirectory(atPath: bundled.path) {
            let src = bundled.appendingPathComponent(item)
            let dst = dest.appendingPathComponent(item)
            try fm.copyItem(at: src, to: dst)
            if item.hasSuffix(".sh") {
                try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dst.path)
            }
        }
        DuckLog.log("[cursor] copied adapter scripts to \(dest.path)")
        return dest
    }

    /// Merge our hook entries into ~/.cursor/hooks.json, preserving the user's
    /// existing hooks and dropping any stale duck entries from a prior install.
    private static func mergeConfig(hooksDir: URL) throws {
        let fm = FileManager.default
        let url = cursorConfigURL
        try fm.createDirectory(at: url.deletingLastPathComponent(),
                               withIntermediateDirectories: true)

        // Load existing config (if any and valid), else start fresh.
        var root: [String: Any] = ["version": 1, "hooks": [:]]
        if let data = fm.contents(atPath: url.path),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            root = json
            if root["version"] == nil { root["version"] = 1 }
        }
        var hooks = root["hooks"] as? [String: Any] ?? [:]

        for (event, script) in hookScripts {
            let command = hooksDir.appendingPathComponent(script).path
            // Keep the user's other hooks for this event; drop only ours
            // (identified by script filename) so re-installing doesn't stack
            // duplicates — including stale entries from an older install path.
            var entries = (hooks[event] as? [[String: Any]] ?? []).filter { entry in
                guard let cmd = entry["command"] as? String else { return true }
                return !isOurCommand(cmd)
            }
            entries.append(["command": command])
            hooks[event] = entries
        }
        root["hooks"] = hooks

        let out = try JSONSerialization.data(withJSONObject: root,
                                             options: [.prettyPrinted, .sortedKeys])
        try out.write(to: url, options: .atomic)
        DuckLog.log("[cursor] merged hooks into \(url.path)")
    }

    // MARK: - Uninstall

    /// Remove our hook entries (and empty event arrays) from hooks.json. Leaves
    /// the user's own hooks intact. The copied scripts are left in place — they
    /// do nothing once unreferenced — but we remove them too for tidiness.
    @MainActor
    static func uninstall() {
        let fm = FileManager.default
        let url = cursorConfigURL
        if let data = fm.contents(atPath: url.path),
           var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           var hooks = root["hooks"] as? [String: Any] {
            for (event, _) in hookScripts {
                guard var entries = hooks[event] as? [[String: Any]] else { continue }
                entries.removeAll { ($0["command"] as? String).map(isOurCommand) == true }
                if entries.isEmpty { hooks.removeValue(forKey: event) } else { hooks[event] = entries }
            }
            root["hooks"] = hooks
            if let out = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]) {
                try? out.write(to: url, options: .atomic)
            }
        }
        try? fm.removeItem(at: installedHooksDir)
        onSpeak?("Disconnected from Cursor.")
        DuckLog.log("[cursor] uninstalled hooks")
    }

    // MARK: - Bundled location

    /// Find the bundled cursor/hooks folder — inside the app bundle Resources,
    /// or next to the running app during dev. Mirrors PluginInstaller.findBundledPlugin.
    private static func findBundledHooks() -> URL? {
        let fm = FileManager.default
        if let resourcePath = Bundle.main.resourcePath {
            let dir = URL(fileURLWithPath: resourcePath)
                .appendingPathComponent("cursor/hooks")
            if fm.fileExists(atPath: dir.appendingPathComponent("on-permission.sh").path) {
                return dir
            }
        }
        // Dev layout: walk up from the bundle to the repo root and use cursor/hooks.
        var candidate = Bundle.main.bundleURL
        for _ in 0..<10 {
            candidate = candidate.deletingLastPathComponent()
            let dir = candidate.appendingPathComponent("cursor/hooks")
            if fm.fileExists(atPath: dir.appendingPathComponent("on-permission.sh").path) {
                return dir
            }
        }
        return nil
    }

    // MARK: - First-run spoken offer

    /// UserDefaults key tracking the last app version for which we voiced the
    /// Cursor offer — so we suggest it once per version, not every launch.
    private static var offerShownVersion: String? {
        get { UserDefaults.standard.string(forKey: "cursorOfferShownVersion") }
        set { UserDefaults.standard.set(newValue, forKey: "cursorOfferShownVersion") }
    }

    /// Called shortly after launch. If Cursor is installed but our hooks aren't
    /// wired up yet, the duck offers — out loud — to connect itself. Fires at
    /// most once per app version so it doesn't nag.
    @MainActor
    static func offerIfAppropriate() {
        guard isCursorInstalled(), !areHooksInstalled() else { return }
        let running = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        guard offerShownVersion != running else { return }
        offerShownVersion = running
        DuckLog.log("[cursor] offering Cursor hook install (v\(running))")
        onSpeak?("Oh — you've got Cursor. I work there now too. Hit Connect to Cursor in my menu.")
    }

    // MARK: - Result alert

    @MainActor
    private static func showResult(success: Bool, detail: String) {
        showInstallResult(title: "Cursor Hooks Installed", success: success, detail: detail)
    }

    enum CursorError: LocalizedError {
        case bundledHooksMissing
        var errorDescription: String? {
            switch self {
            case .bundledHooksMissing:
                return "Couldn't find the bundled Cursor hook scripts inside the app."
            }
        }
    }
}
