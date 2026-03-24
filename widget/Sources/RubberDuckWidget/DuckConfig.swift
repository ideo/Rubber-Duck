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

    // MARK: - Experimental Features

    static var experimentalEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "experimentalEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "experimentalEnabled") }
    }

    // MARK: - API Keys (Generic)

    /// Resolve an API key from env var → Application Support file.
    private static func resolveKey(envVar: String, filename: String) -> String? {
        if let envKey = ProcessInfo.processInfo.environment[envVar], !envKey.isEmpty {
            return envKey
        }
        let keyFile = storageDir.appendingPathComponent(filename)
        if let fileKey = try? String(contentsOf: keyFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
           !fileKey.isEmpty {
            return fileKey
        }
        return nil
    }

    /// Save an API key to Application Support.
    private static func saveKey(_ key: String, filename: String, label: String) {
        let keyFile = storageDir.appendingPathComponent(filename)
        do {
            try key.write(to: keyFile, atomically: true, encoding: .utf8)
            print("[config] \(label) API key saved to \(keyFile.path)")
        } catch {
            print("[config] Failed to save \(label) API key: \(error)")
        }
    }

    /// Remove a saved API key.
    private static func removeKey(filename: String, label: String) {
        let keyFile = storageDir.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: keyFile)
        print("[config] \(label) API key removed")
    }

    /// Ensure an API key is available, prompting if needed. Returns true if ready.
    @MainActor
    private static func ensureKey(
        currentKey: String,
        title: String, message: String, placeholder: String,
        save: (String) -> Void
    ) -> Bool {
        if !currentKey.isEmpty { return true }
        if let key = promptForAPIKey(title: title, message: message, placeholder: placeholder) {
            save(key)
            return true
        }
        return false
    }

    /// Show a blocking dialog to ask the user for an API key.
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
        alert.window.initialFirstResponder = textField

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let key = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty { return key }
        }
        return nil
    }

    // MARK: - Anthropic API

    static var anthropicAPIKey: String = {
        resolveKey(envVar: "ANTHROPIC_API_KEY", filename: "api_key") ?? ""
    }()

    static func saveAPIKey(_ key: String) {
        saveKey(key, filename: "api_key", label: "Anthropic")
        anthropicAPIKey = key
    }

    static func removeAPIKey() {
        removeKey(filename: "api_key", label: "Anthropic")
        anthropicAPIKey = ""
    }

    @MainActor
    static func ensureAPIKey() -> Bool {
        ensureKey(
            currentKey: anthropicAPIKey,
            title: "Anthropic API Key",
            message: "Enter your Anthropic API key to use Claude for evaluation.\n\nGet one at console.anthropic.com → API Keys.",
            placeholder: "sk-ant-...",
            save: saveAPIKey
        )
    }

    // MARK: - Gemini API

    static var geminiAPIKey: String = {
        resolveKey(envVar: "GEMINI_API_KEY", filename: "gemini_api_key") ?? ""
    }()

    static func saveGeminiAPIKey(_ key: String) {
        saveKey(key, filename: "gemini_api_key", label: "Gemini")
        geminiAPIKey = key
    }

    static func removeGeminiAPIKey() {
        removeKey(filename: "gemini_api_key", label: "Gemini")
        geminiAPIKey = ""
    }

    @MainActor
    static func ensureGeminiAPIKey() -> Bool {
        ensureKey(
            currentKey: geminiAPIKey,
            title: "Gemini API Key",
            message: "Enter your Google Gemini API key for evaluation.\n\nGet one at aistudio.google.com → API Keys.",
            placeholder: "AIza...",
            save: saveGeminiAPIKey
        )
    }

    // MARK: - Duck Mode

    /// Persisted duck mode. Defaults to `.companion`.
    static var duckMode: DuckMode {
        get {
            if let raw = UserDefaults.standard.string(forKey: "duck_mode"),
               let mode = DuckMode(rawValue: raw) {
                return mode
            }
            return .companion
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "duck_mode")
        }
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
            return val == 0 && !UserDefaults.standard.bool(forKey: "duck_volume_set") ? 0.65 : val
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
