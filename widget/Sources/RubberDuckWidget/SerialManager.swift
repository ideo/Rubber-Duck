// Serial Manager — Publishes device state from a DeviceTransport.
//
// Uses a DeviceTransport (default: SerialTransport) for Teensy communication.
// Publishes connection state and port name for the UI.
// Wire format defined in DuckProtocol.swift.

import Foundation

@MainActor
class SerialManager: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var portName: String = ""

    /// The concrete serial transport — exposed so SpeechService can use it
    /// for binary audio I/O with ESP32 devices.
    let serialTransport: SerialTransport

    private let transport: DeviceTransport

    /// Called when Teensy sends a line (e.g. "PONG" for ping).
    var onLineReceived: ((String) -> Void)?

    /// Called when Teensy sends "MODE" (physical button press).
    var onModeToggle: (() -> Void)?

    /// Called when device sends VOL,X.XX (button volume change).
    var onVolumeFromDevice: ((Float) -> Void)?

    /// Called when the serial device connects/disconnects (after identity handshake).
    /// Use this to switch audio paths based on connected board type.
    var onDeviceChange: (() -> Void)?

    init(transport: SerialTransport? = nil) {
        let t = transport ?? {
            let s = SerialTransport()
            s.startReconnectLoop()
            return s
        }()
        self.serialTransport = t
        self.transport = t

        // Forward line events from transport
        t.onLineReceived = { [weak self] line in
            Task { @MainActor in
                if line == "MODE" {
                    self?.onModeToggle?()
                } else if line.hasPrefix("VOL,") {
                    if let vol = Float(line.dropFirst(4)) {
                        self?.onVolumeFromDevice?(vol)
                    }
                } else {
                    self?.onLineReceived?(line)
                }
            }
        }

        // Sync published state when device hot-plugs/unplugs
        t.onConnectionChange = { [weak self] in
            Task { @MainActor in
                self?.syncState()
                self?.onDeviceChange?()
            }
        }

        t.connect()
        syncState()
    }

    // MARK: - Send

    /// Send evaluation scores to Teensy.
    func sendScores(_ scores: EvalScores, source: String) {
        let evalSource: EvalSource = source == "user" ? .user : .claude
        let message = SerialScoreMessage(scores: scores, source: evalSource)
        transport.sendScores(message)
        syncState()
    }

    /// Send a raw command string.
    func sendCommand(_ cmd: String) {
        transport.sendCommand(cmd)
    }

    // MARK: - Connection

    func connect() {
        transport.connect()
        syncState()
    }

    func disconnect() {
        transport.disconnect()
        syncState()
    }

    private func syncState() {
        isConnected = transport.isConnected
        portName = transport.deviceName
    }
}
