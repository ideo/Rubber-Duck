// Duck Config — Centralized configuration with environment variable overrides.
//
// All hardcoded assumptions (URLs, device patterns, audio names) live here.
// Defaults match the current computer-attached setup. Override via env vars
// for alternate configurations (network service, BLE device, etc).

import Foundation

enum DuckConfig {

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
    /// Lookup order: ANTHROPIC_API_KEY env var → ~/.duck/api_key file → service/.env file
    static let anthropicAPIKey: String = {
        // 1. Environment variable (highest priority)
        if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !envKey.isEmpty {
            return envKey
        }

        // 2. ~/.duck/api_key file
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let keyFile = homeDir.appendingPathComponent(".duck/api_key")
        if let fileKey = try? String(contentsOf: keyFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
           !fileKey.isEmpty {
            return fileKey
        }

        // 3. service/.env file (for dev — walk up from binary to find repo)
        if let envKey = loadFromDotEnv(key: "ANTHROPIC_API_KEY") {
            return envKey
        }

        print("[config] WARNING: No ANTHROPIC_API_KEY found. Set via env var or ~/.duck/api_key")
        return ""
    }()

    /// Load a key from the service/.env file by walking up from the binary to find the repo root.
    private static func loadFromDotEnv(key: String) -> String? {
        var dir = Bundle.main.bundleURL
        for _ in 0..<10 {
            dir = dir.deletingLastPathComponent()
            let envFile = dir.appendingPathComponent("service/.env")
            guard let contents = try? String(contentsOf: envFile, encoding: .utf8) else { continue }

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
}
