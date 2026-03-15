// Serial Transport — DeviceTransport implementation using POSIX serial.
//
// Communicates with duck hardware (Teensy or ESP32) over USB serial.
// Auto-detects port by scanning /dev/tty.usbmodem* devices.
// Supports both text lines and binary frames (for audio streaming).
// Includes automatic reconnection on disconnect.

import Foundation

class SerialTransport: DeviceTransport {
    private(set) var isConnected: Bool = false
    private(set) var deviceName: String = ""
    var onLineReceived: ((String) -> Void)?
    var onConnectionChange: (() -> Void)?

    /// Called when a binary frame arrives (tag, payload). Used for mic audio (0x04).
    var onBinaryFrame: ((UInt8, Data) -> Void)?

    /// Called when firmware signals chirp completion ("K\n").
    var onChirpDone: (() -> Void)?

    /// Board identity from handshake (e.g. "ESP32S3", "TEENSY40"). Nil until identified.
    private(set) var connectedBoard: String?

    /// When true, writeString() wraps text in binary control frames (0x02)
    /// so the firmware can parse them during audio mode.
    private(set) var inAudioMode: Bool = false

    /// Enter audio mode — text commands will be wrapped in binary control frames.
    func enterAudioMode() { inAudioMode = true }

    /// Exit audio mode — text commands sent as plain strings again.
    func exitAudioMode() { inAudioMode = false }

    private var fileDescriptor: Int32 = -1
    private var reconnectTask: Task<Void, Never>?
    private var readTask: Task<Void, Never>?

    // 921600 nominal — USB CDC ignores baud but this signals fast link to serial monitors.
    // Teensy CDC also ignores baud, so this is safe for both boards.
    private let baudRate: speed_t = 921600

    deinit {
        reconnectTask?.cancel()
        readTask?.cancel()
        if fileDescriptor >= 0 {
            close(fileDescriptor)
        }
    }

    func connect() {
        for port in findSerialPorts() {
            openPort(port)
            // openPort starts reading + requests identity.
            // If it failed to open, try the next candidate.
            if fileDescriptor < 0 { continue }
            return // Successfully opened — identity check runs async.
        }
    }

    func disconnect() {
        guard fileDescriptor >= 0 else { return }
        let wasIdentified = connectedBoard != nil
        close(fileDescriptor)
        fileDescriptor = -1
        isConnected = false
        deviceName = ""
        connectedBoard = nil
        // Clear rejected ports when a real device disconnects (unplug),
        // so we retry all ports in case a different device appears.
        if wasIdentified {
            rejectedPorts.removeAll()
        }
        print("[serial] Disconnected")
        onConnectionChange?()
    }

    func sendScores(_ message: SerialScoreMessage) {
        writeString(message.wireFormat)
    }

    func sendCommand(_ command: String) {
        writeString(command + "\n")
    }

    /// Write raw bytes (for binary audio frames).
    func writeBytes(_ data: [UInt8]) {
        guard fileDescriptor >= 0 else { return }
        let written = data.withUnsafeBufferPointer { ptr in
            write(fileDescriptor, ptr.baseAddress, data.count)
        }
        if written < 0 {
            print("[serial] Write failed, reconnecting...")
            disconnect()
        }
    }

    /// Write a binary-framed audio packet: [tag][len_hi][len_lo][payload].
    func writeFrame(tag: UInt8, payload: [UInt8]) {
        let len = UInt16(payload.count)
        var frame = [tag, UInt8((len >> 8) & 0xFF), UInt8(len & 0xFF)]
        frame.append(contentsOf: payload)
        writeBytes(frame)
    }

    /// Start auto-reconnection polling.
    func startReconnectLoop() {
        reconnectTask = Task {
            while !Task.isCancelled {
                if !self.isConnected {
                    self.connect()
                }
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
            }
        }
    }

    /// Whether the connected device is an ESP32 (serial audio path).
    var isESP32: Bool {
        connectedBoard?.hasPrefix("ESP32") ?? false
    }

    /// Whether the connected device is a Teensy (UAC audio path).
    var isTeensy: Bool {
        connectedBoard?.hasPrefix("TEENSY") ?? false
    }

    // MARK: - Discovery

    /// Previously-rejected ports (no DUCK identity). Cleared when a device disconnects
    /// so we retry if the user plugs in a different device on the same port.
    private var rejectedPorts: Set<String> = []

    private func findSerialPorts() -> [String] {
        let fileManager = FileManager.default
        do {
            let devContents = try fileManager.contentsOfDirectory(atPath: "/dev")
            let prefix = DuckConfig.serialDevicePrefix
            let cuPrefix = prefix.hasPrefix("tty.") ? "cu." + prefix.dropFirst(4) : "cu.usbmodem"
            let candidates = devContents.filter { name in
                name.hasPrefix(prefix) || name.hasPrefix(cuPrefix)
            }.sorted()

            // Prefer tty over cu, filter out rejected ports
            let ttyFirst = candidates.filter { $0.hasPrefix("tty.") } +
                           candidates.filter { $0.hasPrefix("cu.") }
            return ttyFirst
                .map { "/dev/\($0)" }
                .filter { !rejectedPorts.contains($0) }
        } catch {
            return []
        }
    }

    // MARK: - Port Management

    private func openPort(_ path: String) {
        fileDescriptor = open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard fileDescriptor >= 0 else {
            print("[serial] Failed to open \(path)")
            return
        }

        // Configure terminal settings
        var options = termios()
        tcgetattr(fileDescriptor, &options)

        cfsetispeed(&options, baudRate)
        cfsetospeed(&options, baudRate)

        // 8N1, no flow control
        options.c_cflag |= UInt(CS8)
        options.c_cflag &= ~UInt(PARENB)
        options.c_cflag &= ~UInt(CSTOPB)
        options.c_cflag &= ~UInt(CRTSCTS)
        options.c_cflag |= UInt(CLOCAL | CREAD)

        // Raw mode
        options.c_lflag &= ~UInt(ICANON | ECHO | ECHOE | ISIG)
        options.c_iflag &= ~UInt(IXON | IXOFF | IXANY)
        options.c_oflag &= ~UInt(OPOST)

        tcsetattr(fileDescriptor, TCSANOW, &options)

        // Clear O_NONBLOCK after setup
        _ = fcntl(fileDescriptor, F_SETFL, 0)

        isConnected = true
        deviceName = path
        inAudioMode = false
        print("[serial] Connected to \(path)")

        // Reset firmware to text mode in case it's stuck in audio mode
        // from a previous session. Send A,0 as a binary control frame
        // (works if in audio mode) AND as raw text (works if in text mode).
        let resetPayload = Array("A,0\n".utf8)
        writeFrame(tag: 0x02, payload: resetPayload)
        writeString("A,0\n")

        startReading()
        requestIdentity()
    }

    /// Send identity request — if no DUCK response within 500ms, reject this port.
    private func requestIdentity() {
        writeString("I\n")

        let port = deviceName
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if self.connectedBoard == nil {
                print("[serial] No DUCK identity from \(port) — rejecting")
                self.rejectedPorts.insert(port)
                self.disconnect()
            } else {
                self.onConnectionChange?()
            }
        }
    }

    private func writeString(_ str: String) {
        guard fileDescriptor >= 0 else { return }

        // If firmware is in audio mode, wrap text as a binary control frame
        // so it gets parsed correctly instead of being eaten by the binary parser.
        if inAudioMode {
            let payload = Array(str.utf8)
            writeFrame(tag: 0x02, payload: payload)
            return
        }

        let data = Array(str.utf8)
        let written = data.withUnsafeBufferPointer { ptr in
            write(fileDescriptor, ptr.baseAddress, data.count)
        }
        if written < 0 {
            print("[serial] Write failed, reconnecting...")
            disconnect()
        }
    }

    // MARK: - Read (text + binary)

    // Binary frame tags we recognize in the serial stream.
    // 0x04 = mic audio frame from ESP32 (MIC_FRAME_TAG in Config.h).
    private static let micFrameTag: UInt8 = 0x04

    private func startReading() {
        readTask?.cancel()
        let fd = fileDescriptor
        let transport = self
        readTask = Task.detached {
            var buffer = [UInt8](repeating: 0, count: 4096)
            var pending = Data()

            while !Task.isCancelled && fd >= 0 {
                let bytesRead = read(fd, &buffer, buffer.count)
                if bytesRead > 0 {
                    pending.append(contentsOf: buffer[0..<bytesRead])
                    transport.processPending(&pending)
                } else if bytesRead == 0 {
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                } else {
                    // Read error — device unplugged or connection lost
                    print("[serial] Read error (device unplugged?) — disconnecting")
                    transport.disconnect()
                    break
                }
            }
        }
    }

    /// Process accumulated bytes: extract text lines and binary frames.
    /// Binary frames (0x04 tag) can appear interleaved with text.
    private func processPending(_ data: inout Data) {
        while !data.isEmpty {
            let first = data[data.startIndex]

            // Binary frame? Tag 0x04 + 2-byte big-endian length + payload.
            if first == Self.micFrameTag {
                // Need at least 3 bytes for header
                guard data.count >= 3 else { return } // Wait for more data

                let lenHi = UInt16(data[data.startIndex + 1])
                let lenLo = UInt16(data[data.startIndex + 2])
                let payloadLen = Int((lenHi << 8) | lenLo)

                // Sanity check
                guard payloadLen > 0, payloadLen <= 2048 else {
                    // Bad frame — skip this byte and try to resync
                    data.removeFirst()
                    continue
                }

                let totalFrameLen = 3 + payloadLen
                guard data.count >= totalFrameLen else { return } // Wait for more data

                let payload = data.subdata(in: (data.startIndex + 3)..<(data.startIndex + totalFrameLen))
                data.removeFirst(totalFrameLen)

                onBinaryFrame?(first, payload)
                continue
            }

            // Text: consume bytes until newline.
            // Any byte < 0x20 that isn't \n or \r is skipped (noise).
            if let newlineIdx = data.firstIndex(of: 0x0A) { // \n
                let lineData = data[data.startIndex..<newlineIdx]
                data.removeFirst(data.distance(from: data.startIndex, to: newlineIdx) + 1)

                if let line = String(bytes: lineData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !line.isEmpty {

                    // Intercept identity response before forwarding
                    if line.hasPrefix("DUCK,") {
                        parseIdentity(line)
                    } else if line == "K" {
                        onChirpDone?()
                    } else {
                        onLineReceived?(line)
                    }
                }
                continue
            }

            // No newline yet — wait for more data.
            // But if we have a lot of pending data with no newline, it might be
            // binary garbage. Don't let it grow unbounded.
            if data.count > 8192 {
                data.removeAll()
            }
            return
        }
    }

    /// Parse "DUCK,ESP32S3,1.0" identity response.
    private func parseIdentity(_ line: String) {
        let parts = line.split(separator: ",")
        guard parts.count >= 3, parts[0] == "DUCK" else { return }
        connectedBoard = String(parts[1])
        let version = String(parts[2])
        print("[serial] Identified: \(connectedBoard!) v\(version)")
    }
}
