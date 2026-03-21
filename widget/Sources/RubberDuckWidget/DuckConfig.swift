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
    /// Unsandboxed: ~/Library/Application Support/DuckDuckDuck/
    /// Sandboxed: ~/Library/Containers/com.duckduckduck.widget/Data/Library/Application Support/DuckDuckDuck/
    static let storageDir: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("DuckDuckDuck")
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

    // MARK: - Eval Provider

    /// Which eval engine to use.
    enum EvalProvider: String {
        case foundation  // On-device Foundation Models (free, Apple Silicon only)
        case anthropic   // Anthropic API (requires API key)
        case gemini      // Google Gemini API (requires API key)
    }

    /// Current eval provider. Defaults to `.foundation` (free, no API key needed).
    static var evalProvider: EvalProvider {
        get {
            if let raw = UserDefaults.standard.string(forKey: "evalProvider"),
               let provider = EvalProvider(rawValue: raw) {
                return provider
            }
            return .foundation
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "evalProvider")
        }
    }

    // MARK: - Anthropic API

    /// Anthropic API key for Claude evaluations.
    /// Lookup order: ANTHROPIC_API_KEY env var → Application Support key file → prompt user
    static var anthropicAPIKey: String = {
        if let key = resolveAPIKey() { return key }
        print("[config] WARNING: No ANTHROPIC_API_KEY found. Will prompt on launch.")
        return ""
    }()

    /// Try all automatic sources for the API key (sandbox-safe only).
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

    /// Remove the saved Anthropic API key and clear the in-memory value.
    static func removeAPIKey() {
        let keyFile = storageDir.appendingPathComponent("api_key")
        try? FileManager.default.removeItem(at: keyFile)
        anthropicAPIKey = ""
        print("[config] Anthropic API key removed")
    }

    /// Ensure an Anthropic API key is available. Prompts the user if needed.
    /// Returns true if a key is ready, false if the user cancelled.
    @MainActor
    static func ensureAPIKey() -> Bool {
        if !anthropicAPIKey.isEmpty { return true }
        if let key = promptForAPIKey(
            title: "Anthropic API Key",
            message: "Enter your Anthropic API key to use Claude for evaluation.\n\nGet one at console.anthropic.com → API Keys.",
            placeholder: "sk-ant-..."
        ) {
            saveAPIKey(key)
            return true
        }
        return false
    }

    // MARK: - Gemini API

    /// Gemini API key for Google evaluations.
    /// Lookup order: GEMINI_API_KEY env var → Application Support key file → prompt user
    static var geminiAPIKey: String = {
        if let key = resolveGeminiAPIKey() { return key }
        print("[config] WARNING: No GEMINI_API_KEY found. Will prompt on launch.")
        return ""
    }()

    /// Try all automatic sources for the Gemini API key (sandbox-safe only).
    private static func resolveGeminiAPIKey() -> String? {
        // 1. Environment variable (highest priority)
        if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !envKey.isEmpty {
            return envKey
        }

        // 2. Application Support key file (sandbox-safe)
        let keyFile = storageDir.appendingPathComponent("gemini_api_key")
        if let fileKey = try? String(contentsOf: keyFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
           !fileKey.isEmpty {
            return fileKey
        }

        return nil
    }

    /// Save a Gemini API key to Application Support and update the in-memory value.
    static func saveGeminiAPIKey(_ key: String) {
        let keyFile = storageDir.appendingPathComponent("gemini_api_key")

        do {
            try key.write(to: keyFile, atomically: true, encoding: .utf8)
            geminiAPIKey = key
            print("[config] Gemini API key saved to \(keyFile.path)")
        } catch {
            print("[config] Failed to save Gemini API key: \(error)")
        }
    }

    /// Remove the saved Gemini API key and clear the in-memory value.
    static func removeGeminiAPIKey() {
        let keyFile = storageDir.appendingPathComponent("gemini_api_key")
        try? FileManager.default.removeItem(at: keyFile)
        geminiAPIKey = ""
        print("[config] Gemini API key removed")
    }

    /// Ensure a Gemini API key is available. Prompts the user if needed.
    /// Returns true if a key is ready, false if the user cancelled.
    @MainActor
    static func ensureGeminiAPIKey() -> Bool {
        if !geminiAPIKey.isEmpty { return true }
        if let key = promptForAPIKey(
            title: "Gemini API Key",
            message: "Enter your Google Gemini API key for evaluation.\n\nGet one at aistudio.google.com → API Keys.",
            placeholder: "AIza..."
        ) {
            saveGeminiAPIKey(key)
            return true
        }
        return false
    }

    // MARK: - Shared API Key Prompt

    /// Show a blocking dialog to ask the user for an API key. Returns the key or nil if cancelled.
    @MainActor
    private static func promptForAPIKey(title: String, message: String, placeholder: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 24))
        textField.placeholderString = placeholder
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

    /// Substrings to match when searching CoreAudio for any duck UAC device.
    /// Matches Teensy ("Teensy MIDI_Audio") and ESP32-S3 ("Duck Duck Duck").
    /// Override the S3 name: DUCK_S3_AUDIO_DEVICE_NAME=...
    static let duckAudioDeviceNames: [String] = {
        let s3Name = ProcessInfo.processInfo.environment["DUCK_S3_AUDIO_DEVICE_NAME"] ?? "duck duck duck"
        return [teensyAudioDeviceName, s3Name.lowercased()]
    }()

    // MARK: - TTS

    /// Voice for macOS `say` command.
    /// Override: DUCK_VOICE=Samantha
    static let ttsVoice: String = {
        ProcessInfo.processInfo.environment["DUCK_VOICE"] ?? "Boing"
    }()

    /// Master volume (0.0–1.0). Controls TTS output and firmware chirp level.
    static var volume: Float {
        get {
            let val = UserDefaults.standard.float(forKey: "duck_volume")
            return val == 0 && !UserDefaults.standard.bool(forKey: "duck_volume_set") ? 0.8 : val
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "duck_volume")
            UserDefaults.standard.set(true, forKey: "duck_volume_set")
        }
    }

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

    // MARK: - PID File

    /// PID file path — in Application Support for sandbox safety.
    static let pidFilePath: String = {
        storageDir.appendingPathComponent("duck.pid").path
    }()

}
