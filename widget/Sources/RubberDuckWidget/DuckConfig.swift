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
    static let preferredPort: Int = {
        if let override = ProcessInfo.processInfo.environment["DUCK_SERVICE_PORT"],
           let port = Int(override) {
            return port
        }
        return 3333
    }()

    /// The actual port the server bound to (may differ from preferred if port was taken).
    static var activePort: Int = 3333

    /// Write the active port + PID to Application Support so hooks can find us.
    static func writePortFile() {
        let portFile = storageDir.appendingPathComponent("port")
        let pidFile = storageDir.appendingPathComponent("port.pid")
        try? "\(activePort)".write(to: portFile, atomically: true, encoding: .utf8)
        try? "\(ProcessInfo.processInfo.processIdentifier)".write(to: pidFile, atomically: true, encoding: .utf8)
        DuckLog.log("[config] Port file written: \(activePort) (pid \(ProcessInfo.processInfo.processIdentifier))")
    }

    /// Remove port + PID files on shutdown.
    static func removePortFile() {
        let fm = FileManager.default
        try? fm.removeItem(at: storageDir.appendingPathComponent("port"))
        try? fm.removeItem(at: storageDir.appendingPathComponent("port.pid"))
    }

    /// Clean up stale port file left by a crashed/killed previous instance.
    /// Call this on launch, before starting the server.
    static func cleanStalePortFile() {
        let portFile = storageDir.appendingPathComponent("port")
        let pidFile = storageDir.appendingPathComponent("port.pid")
        let fm = FileManager.default

        guard fm.fileExists(atPath: portFile.path) else { return }

        // If there's a PID file, check if that process is still alive
        if let pidStr = try? String(contentsOf: pidFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
           let pid = Int32(pidStr) {
            let alive = kill(pid, 0) == 0  // signal 0 = just check existence
            if alive {
                DuckLog.log("[config] Previous instance (pid \(pid)) still running — leaving port file")
                return
            }
        }

        // Stale — remove both files
        DuckLog.log("[config] Cleaning stale port file from crashed/killed previous instance")
        try? fm.removeItem(at: portFile)
        try? fm.removeItem(at: pidFile)
    }

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

    // MARK: - Subtitles

    /// Show speech bubbles even when audio is playing.
    static var subtitlesEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "subtitles_enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "subtitles_enabled") }
    }

    // MARK: - Legal Disclaimer

    /// App version when the disclaimer was last accepted. Nil = never accepted.
    /// Re-shows on every app update (any version change).
    static var disclaimerAcceptedVersion: String? {
        get { UserDefaults.standard.string(forKey: "disclaimerAcceptedVersion") }
        set { UserDefaults.standard.set(newValue, forKey: "disclaimerAcceptedVersion") }
    }

    /// Whether the disclaimer needs to be shown (first launch or post-update).
    static var needsDisclaimer: Bool {
        let running = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        return disclaimerAcceptedVersion != running
    }

    // MARK: - Chip Detection

    /// True if running on M1 or M2 Apple Silicon (including Pro/Max/Ultra variants).
    /// On-device Foundation Models eval is ~60s on these chips vs sub-second on M3+.
    static let isOlderAppleSilicon: Bool = {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var brand = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
        let chip = String(cString: brand)
        return chip.contains("M1") || chip.contains("M2")
    }()

    // MARK: - Experimental Features

    static var experimentalEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "experimentalEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "experimentalEnabled") }
    }

    /// Tiange's Hollow — summons the doppelganger twin that caroms around
    /// the screen and body-checks the main duck. Persisted so the twin
    /// returns at its last known state across app launches.
    static var tiangesHollowEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "tiangesHollowEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "tiangesHollowEnabled") }
    }

    // MARK: - Update Checking

    /// Last app version that ran (detects post-update first launch).
    static var lastRunAppVersion: String? {
        get { UserDefaults.standard.string(forKey: "lastRunAppVersion") }
        set { UserDefaults.standard.set(newValue, forKey: "lastRunAppVersion") }
    }

    /// Plugin version that was last successfully installed.
    static var lastInstalledPluginVersion: Int? {
        get {
            let v = UserDefaults.standard.integer(forKey: "lastInstalledPluginVersion")
            return v == 0 && !UserDefaults.standard.bool(forKey: "lastInstalledPluginVersion_set") ? nil : v
        }
        set {
            UserDefaults.standard.set(newValue ?? 0, forKey: "lastInstalledPluginVersion")
            UserDefaults.standard.set(true, forKey: "lastInstalledPluginVersion_set")
        }
    }

    /// Unix timestamp of last GitHub update check.
    static var lastUpdateCheckTimestamp: Double? {
        get {
            let v = UserDefaults.standard.double(forKey: "lastUpdateCheckTimestamp")
            return v == 0 ? nil : v
        }
        set { UserDefaults.standard.set(newValue ?? 0, forKey: "lastUpdateCheckTimestamp") }
    }

    // MARK: - API Keys (File-based in Application Support)

    /// Resolve an API key: env var → file in sandbox container.
    private static func resolveKey(envVar: String, filename: String, keychainAccount: String) -> String? {
        // 1. Environment variable (dev override)
        if let envKey = ProcessInfo.processInfo.environment[envVar], !envKey.isEmpty {
            return envKey
        }
        // 2. File in Application Support
        let keyFile = storageDir.appendingPathComponent(filename)
        if let fileKey = try? String(contentsOf: keyFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
           !fileKey.isEmpty {
            return fileKey
        }
        return nil
    }

    /// Save an API key to a file in Application Support.
    private static func saveKey(_ key: String, keychainAccount: String, label: String) {
        let filenames: [String: String] = ["Anthropic": "api_key", "Gemini": "gemini_api_key"]
        guard let filename = filenames[label] else { return }
        let keyFile = storageDir.appendingPathComponent(filename)
        do {
            try key.write(to: keyFile, atomically: true, encoding: .utf8)
            // Set file permissions to owner-only (0600)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyFile.path)
            DuckLog.log("[config] \(label) API key saved to file")
        } catch {
            DuckLog.log("[config] Failed to save \(label) API key: \(error)")
        }
    }

    /// Remove an API key file.
    private static func removeKey(keychainAccount: String, label: String) {
        let filenames: [String: String] = ["Anthropic": "api_key", "Gemini": "gemini_api_key"]
        guard let filename = filenames[label] else { return }
        let keyFile = storageDir.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: keyFile)
        DuckLog.log("[config] \(label) API key removed")
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
        resolveKey(envVar: "ANTHROPIC_API_KEY", filename: "api_key", keychainAccount: "anthropic_api_key") ?? ""
    }()

    static func saveAPIKey(_ key: String) {
        saveKey(key, keychainAccount: "anthropic_api_key", label: "Anthropic")
        anthropicAPIKey = key
    }

    static func removeAPIKey() {
        removeKey(keychainAccount: "anthropic_api_key", label: "Anthropic")
        anthropicAPIKey = ""
    }

    @MainActor
    static func ensureAPIKey() -> Bool {
        ensureKey(
            currentKey: anthropicAPIKey,
            title: "Anthropic API Key",
            message: "1. Go to console.anthropic.com and create an account\n2. Add a payment method (pay-as-you-go)\n3. Go to API Keys → Create Key\n4. Copy the key and paste it below\n\nHaiku costs ~$0.001 per eval — pennies for a full day of coding.",
            placeholder: "sk-ant-...",
            save: saveAPIKey
        )
    }

    // MARK: - Gemini API

    static var geminiAPIKey: String = {
        resolveKey(envVar: "GEMINI_API_KEY", filename: "gemini_api_key", keychainAccount: "gemini_api_key") ?? ""
    }()

    static func saveGeminiAPIKey(_ key: String) {
        saveKey(key, keychainAccount: "gemini_api_key", label: "Gemini")
        geminiAPIKey = key
    }

    static func removeGeminiAPIKey() {
        removeKey(keychainAccount: "gemini_api_key", label: "Gemini")
        geminiAPIKey = ""
    }

    @MainActor
    static func ensureGeminiAPIKey() -> Bool {
        ensureKey(
            currentKey: geminiAPIKey,
            title: "Gemini API Key",
            message: "1. Go to aistudio.google.com and sign in with Google\n2. Click Get API Key → Create API Key\n3. Copy the key and paste it below\n\nNo credit card needed. Gemini Flash has a free tier.",
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
            return val == 0 && !UserDefaults.standard.bool(forKey: "duck_volume_set") ? 0.50 : val
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
    /// Note: The server also writes `port.pid` alongside the `port` file
    /// for stale-port detection (see cleanStalePortFile).
    static let pidFilePath: String = {
        storageDir.appendingPathComponent("duck.pid").path
    }()

}
