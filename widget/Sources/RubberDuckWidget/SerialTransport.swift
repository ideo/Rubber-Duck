// Serial Transport — DeviceTransport implementation using POSIX serial.
//
// Communicates with Teensy over USB serial at 9600 baud.
// Auto-detects port by scanning /dev/tty.usbmodem* devices.
// Includes automatic reconnection on disconnect.

import Foundation

class SerialTransport: DeviceTransport {
    private(set) var isConnected: Bool = false
    private(set) var deviceName: String = ""
    var onLineReceived: ((String) -> Void)?

    private var fileDescriptor: Int32 = -1
    private var reconnectTask: Task<Void, Never>?
    private var readTask: Task<Void, Never>?
    private let baudRate: speed_t = 9600

    deinit {
        reconnectTask?.cancel()
        readTask?.cancel()
        if fileDescriptor >= 0 {
            close(fileDescriptor)
        }
    }

    func connect() {
        if let port = findTeensyPort() {
            openPort(port)
        }
    }

    func disconnect() {
        guard fileDescriptor >= 0 else { return }
        close(fileDescriptor)
        fileDescriptor = -1
        isConnected = false
        deviceName = ""
        print("[serial] Disconnected")
    }

    func sendScores(_ message: SerialScoreMessage) {
        writeString(message.wireFormat)
    }

    func sendCommand(_ command: String) {
        writeString(command + "\n")
    }

    /// Start auto-reconnection polling.
    func startReconnectLoop() {
        reconnectTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3s
                if !self.isConnected {
                    self.connect()
                }
            }
        }
    }

    // MARK: - Discovery

    private func findTeensyPort() -> String? {
        let fileManager = FileManager.default
        do {
            let devContents = try fileManager.contentsOfDirectory(atPath: "/dev")
            let prefix = DuckConfig.serialDevicePrefix
            let cuPrefix = prefix.hasPrefix("tty.") ? "cu." + prefix.dropFirst(4) : "cu.usbmodem"
            let candidates = devContents.filter { name in
                name.hasPrefix(prefix) || name.hasPrefix(cuPrefix)
            }.sorted()

            // Prefer tty over cu
            if let tty = candidates.first(where: { $0.hasPrefix("tty.") }) {
                return "/dev/\(tty)"
            }
            return candidates.first.map { "/dev/\($0)" }
        } catch {
            return nil
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
        print("[serial] Connected to \(path)")
        startReading()
    }

    private func writeString(_ str: String) {
        guard fileDescriptor >= 0 else { return }
        let data = Array(str.utf8)
        let written = data.withUnsafeBufferPointer { ptr in
            write(fileDescriptor, ptr.baseAddress, data.count)
        }
        if written < 0 {
            print("[serial] Write failed, reconnecting...")
            disconnect()
        }
    }

    // MARK: - Read

    private func startReading() {
        readTask?.cancel()
        let fd = fileDescriptor
        readTask = Task.detached { [weak self] in
            var buffer = [UInt8](repeating: 0, count: 256)
            var lineBuffer = ""

            while !Task.isCancelled && fd >= 0 {
                let bytesRead = read(fd, &buffer, buffer.count)
                if bytesRead > 0 {
                    let chunk = String(bytes: buffer[0..<bytesRead], encoding: .utf8) ?? ""
                    lineBuffer += chunk

                    while let newlineRange = lineBuffer.range(of: "\n") {
                        let line = String(lineBuffer[lineBuffer.startIndex..<newlineRange.lowerBound])
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        lineBuffer = String(lineBuffer[newlineRange.upperBound...])

                        if !line.isEmpty {
                            self?.onLineReceived?(line)
                        }
                    }
                } else if bytesRead == 0 {
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                } else {
                    break // Read error — connection lost
                }
            }
        }
    }
}
