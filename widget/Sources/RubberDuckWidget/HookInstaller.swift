// Hook Installer — Extracts bundled hook scripts to ~/.duck/hooks/
// and registers them in ~/.claude/settings.json (global scope).
//
// Called once on app launch. Idempotent — skips if hooks are already installed.
// Preserves existing user hooks and settings when merging.

import Foundation

enum HookInstaller {

    private static let hookScripts = [
        "on-user-prompt.sh",
        "on-claude-stop.sh",
        "on-permission-request.sh",
        "duck-env.sh",
    ]

    /// Extract scripts to ~/.duck/hooks/ and register in ~/.claude/settings.json.
    /// Skips if the Claude Code plugin is handling hooks instead.
    static func install() {
        let home = FileManager.default.homeDirectoryForCurrentUser

        // If plugin mode is active, the Claude Code plugin handles hooks via
        // HTTP — no need to install shell scripts or modify settings.json.
        let pluginSentinel = home.appendingPathComponent(".duck/.plugin-mode")
        if FileManager.default.fileExists(atPath: pluginSentinel.path) {
            DuckLog.log("[hooks] Plugin mode active — skipping auto-install")
            return
        }

        let hooksDir = home.appendingPathComponent(".duck/hooks")
        let settingsFile = home.appendingPathComponent(".claude/settings.json")

        // 1. Extract scripts from app bundle → ~/.duck/hooks/
        extractScripts(to: hooksDir)

        // 2. Merge hook entries into ~/.claude/settings.json
        mergeSettings(settingsFile: settingsFile, hooksDir: hooksDir)
    }

    /// Remove shell script hooks from ~/.claude/settings.json.
    /// Called when switching to plugin mode.
    static func uninstallHooks() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let settingsFile = home.appendingPathComponent(".claude/settings.json")

        guard let data = try? Data(contentsOf: settingsFile),
              var settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var hooks = settings["hooks"] as? [String: Any] else {
            return
        }

        // Remove entries that reference .duck/hooks/
        for (event, entries) in hooks {
            guard var arr = entries as? [[String: Any]] else { continue }
            arr.removeAll { entry in
                guard let hookList = entry["hooks"] as? [[String: Any]] else { return false }
                return hookList.contains { ($0["command"] as? String)?.contains(".duck/hooks/") == true }
            }
            if arr.isEmpty {
                hooks.removeValue(forKey: event)
            } else {
                hooks[event] = arr
            }
        }

        if hooks.isEmpty {
            settings.removeValue(forKey: "hooks")
        } else {
            settings["hooks"] = hooks
        }

        guard let updated = try? JSONSerialization.data(
            withJSONObject: settings,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return }

        try? updated.write(to: settingsFile)
        DuckLog.log("[hooks] Removed shell script hooks from settings.json")
    }

    /// Enable plugin mode — removes shell hooks and creates sentinel.
    static func enablePluginMode() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let sentinel = home.appendingPathComponent(".duck/.plugin-mode")
        FileManager.default.createFile(atPath: sentinel.path, contents: nil)
        uninstallHooks()
        DuckLog.log("[hooks] Plugin mode enabled")
    }

    /// Disable plugin mode — removes sentinel, next launch will auto-install.
    static func disablePluginMode() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let sentinel = home.appendingPathComponent(".duck/.plugin-mode")
        try? FileManager.default.removeItem(at: sentinel)
        DuckLog.log("[hooks] Plugin mode disabled")
    }

    // MARK: - Extract Scripts

    private static func extractScripts(to hooksDir: URL) {
        let fm = FileManager.default
        try? fm.createDirectory(at: hooksDir, withIntermediateDirectories: true)

        for name in hookScripts {
            let baseName = (name as NSString).deletingPathExtension
            guard let url = Bundle.module.url(forResource: baseName, withExtension: "sh") else {
                DuckLog.log("[hooks] WARNING: \(name) not found in bundle")
                continue
            }
            guard let data = try? Data(contentsOf: url) else {
                DuckLog.log("[hooks] WARNING: Could not read \(name) from bundle")
                continue
            }

            let dest = hooksDir.appendingPathComponent(name)
            do {
                try data.write(to: dest)
                // chmod +x
                try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dest.path)
            } catch {
                DuckLog.log("[hooks] Failed to write \(name): \(error)")
            }
        }

        DuckLog.log("[hooks] Extracted \(hookScripts.count) scripts to \(hooksDir.path)")
    }

    // MARK: - Merge Settings

    private static func mergeSettings(settingsFile: URL, hooksDir: URL) {
        let fm = FileManager.default
        let claudeDir = settingsFile.deletingLastPathComponent()
        try? fm.createDirectory(at: claudeDir, withIntermediateDirectories: true)

        // Read existing settings (or start fresh)
        var settings: [String: Any] = [:]
        if let data = try? Data(contentsOf: settingsFile),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = json
        }

        // Check if our hooks are already registered
        if let hooks = settings["hooks"] as? [String: Any] {
            let allCommands = hooks.values.compactMap { entries -> [String] in
                guard let arr = entries as? [[String: Any]] else { return [] }
                return arr.flatMap { entry -> [String] in
                    guard let hookList = entry["hooks"] as? [[String: Any]] else { return [] }
                    return hookList.compactMap { $0["command"] as? String }
                }
            }.flatMap { $0 }

            if allCommands.contains(where: { $0.contains(".duck/hooks/") }) {
                DuckLog.log("[hooks] Already registered in settings.json — skipping")
                return
            }
        }

        // Build our hook entries
        let hooksPath = hooksDir.path
        let duckHooks: [String: Any] = [
            "UserPromptSubmit": [[
                "matcher": "",
                "hooks": [[
                    "type": "command",
                    "command": "\(hooksPath)/on-user-prompt.sh",
                    "async": true,
                ] as [String: Any]],
            ] as [String: Any]],
            "Stop": [[
                "matcher": "",
                "hooks": [[
                    "type": "command",
                    "command": "\(hooksPath)/on-claude-stop.sh",
                    "async": true,
                ] as [String: Any]],
            ] as [String: Any]],
            "PermissionRequest": [[
                "matcher": "",
                "hooks": [[
                    "type": "command",
                    "command": "\(hooksPath)/on-permission-request.sh",
                    "async": false,
                ] as [String: Any]],
            ] as [String: Any]],
        ]

        // Merge — append our hooks to existing ones (don't overwrite)
        var existingHooks = settings["hooks"] as? [String: Any] ?? [:]
        for (event, entries) in duckHooks {
            if var existing = existingHooks[event] as? [[String: Any]],
               let new = entries as? [[String: Any]] {
                existing.append(contentsOf: new)
                existingHooks[event] = existing
            } else {
                existingHooks[event] = entries
            }
        }
        settings["hooks"] = existingHooks

        // Write back with pretty printing
        guard let data = try? JSONSerialization.data(
            withJSONObject: settings,
            options: [.prettyPrinted, .sortedKeys]
        ) else {
            DuckLog.log("[hooks] Failed to serialize settings.json")
            return
        }

        do {
            try data.write(to: settingsFile)
            DuckLog.log("[hooks] Registered hooks in \(settingsFile.path)")
        } catch {
            DuckLog.log("[hooks] Failed to write settings.json: \(error)")
        }
    }
}
