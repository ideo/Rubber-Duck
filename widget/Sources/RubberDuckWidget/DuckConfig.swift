// Duck Config — Centralized configuration with environment variable overrides.
//
// All hardcoded assumptions (URLs, device patterns, audio names) live here.
// Defaults match the current computer-attached setup. Override via env vars
// for alternate configurations (network service, BLE device, etc).

import AppKit
import Foundation

enum DuckConfig {

    // MARK: - Storage Directory

    /// Application Support directory — sandbox-safe.
    /// Unsandboxed: ~/Library/Application Support/RubberDuck/
    /// Sandboxed: ~/Library/Containers/com.rubberduck.widget/Data/Library/Application Support/RubberDuck/
    static let storageDir: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("RubberDuck")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    // MARK: - Eval Service

    /// HTTP port for the embedded eval server.
    /// Override: DUCK_SERVICE_PORT=4444
    static let servicePort: Int = {
        if let override = ProcessInfo.processInfo.environment["DUCK_SERVICE_PORT"],
           let port = Int(override) {
            return port
        }
        return 3333
    }()

    // MARK: - Anthropic API

    /// Anthropic API key for Claude evaluations.
    /// Lookup order: ANTHROPIC_API_KEY env var → ~/.duck/api_key file → .env file in repo → prompt user
    static var anthropicAPIKey: String = {
        if let key = resolveAPIKey() { return key }
        print("[config] WARNING: No ANTHROPIC_API_KEY found. Will prompt on launch.")
        return ""
    }()

    /// Try all automatic sources for the API key.
    private static func resolveAPIKey() -> String? {
        // 1. Environment variable (highest priority)
        if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !envKey.isEmpty {
            return envKey
        }

        // 2. Application Support key file (sandbox-safe)
        let keyFile = storageDir.appendingPathComponent("api_key")
        if let fileKey = try? String(contentsOf: keyFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
           !fileKey.isEmpty {
            return fileKey
        }

        // 2b. Legacy ~/.duck/api_key (migrate if found)
        let legacyKeyFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".duck/api_key")
        if let legacyKey = try? String(contentsOf: legacyKeyFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
           !legacyKey.isEmpty {
            // Migrate to new location
            try? legacyKey.write(to: keyFile, atomically: true, encoding: .utf8)
            return legacyKey
        }

        // 3. .env file in repo (walk up from binary to find it)
        if let envKey = loadFromDotEnv(key: "ANTHROPIC_API_KEY") {
            return envKey
        }

        return nil
    }

    /// Save an API key to Application Support and update the in-memory value.
    static func saveAPIKey(_ key: String) {
        let keyFile = storageDir.appendingPathComponent("api_key")

        do {
            try key.write(to: keyFile, atomically: true, encoding: .utf8)
            anthropicAPIKey = key
            print("[config] API key saved to \(keyFile.path)")
        } catch {
            print("[config] Failed to save API key: \(error)")
        }
    }

    /// Show a blocking dialog to ask the user for their API key. Returns the key or nil if cancelled.
    @MainActor
    static func promptForAPIKey() -> String? {
        let alert = NSAlert()
        alert.messageText = "Anthropic API Key Required"
        alert.informativeText = "Rubber Duck needs an Anthropic API key to evaluate code.\n\nGet one at console.anthropic.com → API Keys."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Quit")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 24))
        textField.placeholderString = "sk-ant-..."
        textField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        alert.accessoryView = textField

        // Focus the text field
        alert.window.initialFirstResponder = textField

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let key = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty { return key }
        }
        return nil
    }

    /// Load a key from a .env file by walking up from the binary to find the repo root.
    /// Searches for .env and widget/.env at each level.
    private static func loadFromDotEnv(key: String) -> String? {
        var dir = Bundle.main.bundleURL
        for _ in 0..<10 {
            dir = dir.deletingLastPathComponent()
            // Check .env at this level and widget/.env
            for envPath in [dir.appendingPathComponent(".env"),
                            dir.appendingPathComponent("widget/.env")] {
                guard let contents = try? String(contentsOf: envPath, encoding: .utf8) else { continue }

                for line in contents.components(separatedBy: .newlines) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
                    let parts = trimmed.components(separatedBy: "=")
                    guard parts.count >= 2 else { continue }
                    let k = parts[0].trimmingCharacters(in: .whitespaces)
                    if k == key {
                        let v = parts.dropFirst().joined(separator: "=")
                            .trimmingCharacters(in: .whitespaces)
                            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                        if !v.isEmpty { return v }
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Serial / Device

    /// Prefix to match when scanning /dev for Teensy serial ports.
    /// Override: DUCK_SERIAL_PREFIX=tty.usbmodem
    static let serialDevicePrefix: String = {
        ProcessInfo.processInfo.environment["DUCK_SERIAL_PREFIX"] ?? "tty.usbmodem"
    }()

    /// Substring to match when searching CoreAudio devices for Teensy.
    /// Override: DUCK_AUDIO_DEVICE_NAME=Teensy
    static let teensyAudioDeviceName: String = {
        ProcessInfo.processInfo.environment["DUCK_AUDIO_DEVICE_NAME"] ?? "teensy"
    }()

    // MARK: - TTS

    /// Voice for macOS `say` command.
    /// Override: DUCK_VOICE=Samantha
    static let ttsVoice: String = {
        ProcessInfo.processInfo.environment["DUCK_VOICE"] ?? "Boing"
    }()

    // MARK: - tmux

    /// tmux session name for Claude Code.
    /// Override: DUCK_TMUX_SESSION=duck
    static let tmuxSession: String = {
        ProcessInfo.processInfo.environment["DUCK_TMUX_SESSION"] ?? "duck"
    }()

    /// tmux window name for the Claude Code pane.
    /// Override: DUCK_TMUX_WINDOW=claude
    static let tmuxWindow: String = {
        ProcessInfo.processInfo.environment["DUCK_TMUX_WINDOW"] ?? "claude"
    }()

    // MARK: - Runtime Config File

    /// PID file path — in Application Support for sandbox safety.
    static let pidFilePath: String = {
        storageDir.appendingPathComponent("duck.pid").path
    }()

    /// Write resolved runtime values so shell scripts can read them.
    /// Written to Application Support (sandbox-safe) and symlinked from ~/.duck/config
    /// so legacy plugin scripts using `source ~/.duck/config` still work.
    /// Called once on app launch. Format is key=value for direct `source` in bash.
    static func writeRuntimeConfig() {
        let configFile = storageDir.appendingPathComponent("config")

        let contents = """
        # Rubber Duck Runtime Config — written by widget on launch.
        # Do not edit manually; regenerated each launch.
        DUCK_SERVICE_PORT=\(servicePort)
        DUCK_SERVICE_URL=http://localhost:\(servicePort)
        DUCK_TMUX_SESSION=\(tmuxSession)
        DUCK_TMUX_WINDOW=\(tmuxWindow)
        DUCK_PID_FILE=\(pidFilePath)
        DUCK_VOICE=\(ttsVoice)
        DUCK_SERIAL_PREFIX=\(serialDevicePrefix)
        DUCK_AUDIO_DEVICE_NAME=\(teensyAudioDeviceName)
        DUCK_STORAGE_DIR=\(storageDir.path)
        """

        do {
            try contents.write(to: configFile, atomically: true, encoding: .utf8)
            print("[config] Wrote runtime config to \(configFile.path)")
        } catch {
            print("[config] Failed to write config: \(error)")
        }

        // Also write to legacy ~/.duck/config for plugin scripts that source it.
        // This is the ONE remaining write outside Application Support — needed because
        // plugin shell scripts can't easily discover the sandbox container path.
        // When fully sandboxed, the plugin scripts will hardcode port 3333 instead.
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let legacyDir = homeDir.appendingPathComponent(".duck")
        let legacyConfig = legacyDir.appendingPathComponent("config")
        try? FileManager.default.createDirectory(at: legacyDir, withIntermediateDirectories: true)
        try? contents.write(to: legacyConfig, atomically: true, encoding: .utf8)
    }
}
