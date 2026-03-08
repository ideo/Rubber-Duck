// Duck Config — Centralized configuration with environment variable overrides.
//
// All hardcoded assumptions (URLs, device patterns, audio names) live here.
// Defaults match the current computer-attached setup. Override via env vars
// for alternate configurations (network service, BLE device, etc).

import Foundation

enum DuckConfig {

    // MARK: - Eval Service

    /// WebSocket URL for the eval service.
    /// Override: DUCK_SERVICE_URL=ws://192.168.1.50:3333/ws
    static let serviceURL: URL = {
        if let override = ProcessInfo.processInfo.environment["DUCK_SERVICE_URL"],
           let url = URL(string: override) {
            return url
        }
        return URL(string: "ws://localhost:\(servicePort)/ws")!
    }()

    /// HTTP port for the eval service.
    /// Override: DUCK_SERVICE_PORT=4444
    static let servicePort: Int = {
        if let override = ProcessInfo.processInfo.environment["DUCK_SERVICE_PORT"],
           let port = Int(override) {
            return port
        }
        return 3333
    }()

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
