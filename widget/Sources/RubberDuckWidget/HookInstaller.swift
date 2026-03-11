// Hook Installer — LEGACY support only.
//
// The plugin system now handles hook delivery. This file only exists to:
// 1. Clean up old ~/.duck/hooks/ and ~/.claude/settings.json entries from pre-plugin installs
// 2. Provide migration path for users upgrading from the old hook approach
//
// See docs/LEGACY-HOOKS.md for the old architecture.

import Foundation

enum HookInstaller {

    /// Clean up legacy hook artifacts from pre-plugin installs.
    /// Safe to call on every launch — no-ops if nothing to clean.
    static func migrateLegacy() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let legacyHooksDir = home.appendingPathComponent(".duck/hooks")
        let settingsFile = home.appendingPathComponent(".claude/settings.json")

        // Remove old shell script hooks from ~/.claude/settings.json
        removeLegacyHooksFromSettings(settingsFile)

        // Remove old ~/.duck/hooks/ directory
        if FileManager.default.fileExists(atPath: legacyHooksDir.path) {
            try? FileManager.default.removeItem(at: legacyHooksDir)
            DuckLog.log("[hooks] Removed legacy hooks directory")
        }

        // Remove old sentinel file
        let sentinel = home.appendingPathComponent(".duck/.plugin-mode")
        if FileManager.default.fileExists(atPath: sentinel.path) {
            try? FileManager.default.removeItem(at: sentinel)
        }
    }

    /// Remove .duck/hooks/ entries from ~/.claude/settings.json.
    private static func removeLegacyHooksFromSettings(_ settingsFile: URL) {
        guard let data = try? Data(contentsOf: settingsFile),
              var settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var hooks = settings["hooks"] as? [String: Any] else {
            return
        }

        var changed = false
        for (event, entries) in hooks {
            guard var arr = entries as? [[String: Any]] else { continue }
            let before = arr.count
            arr.removeAll { entry in
                guard let hookList = entry["hooks"] as? [[String: Any]] else { return false }
                return hookList.contains { ($0["command"] as? String)?.contains(".duck/hooks/") == true }
            }
            if arr.count != before {
                changed = true
                if arr.isEmpty {
                    hooks.removeValue(forKey: event)
                } else {
                    hooks[event] = arr
                }
            }
        }

        guard changed else { return }

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
        DuckLog.log("[hooks] Cleaned legacy hooks from settings.json")
    }
}
