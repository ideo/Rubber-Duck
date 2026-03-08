// Serial Manager — POSIX serial communication with Teensy.
//
// Sends evaluation scores to the Teensy over USB serial.
// Auto-detects Teensy by scanning /dev/tty.usbmodem* ports.
// Protocol: {U|C},creativity,soundness,ambition,elegance,risk\n

import Foundation

@MainActor
class SerialManager: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var portName: String = ""

    private var fileDescriptor: Int32 = -1
    private var reconnectTask: Task<Void, Never>?
    private var readTask: Task<Void, Never>?
    private let baudRate: speed_t = 9600

    /// Called when Teensy sends a line (e.g. "Y" or "N" for permission)
    var onLineReceived: ((String) -> Void)?

    init() {
        connect()
        startReconnectLoop()
    }

    deinit {
        reconnectTask?.cancel()
        readTask?.cancel()
        if fileDescriptor >= 0 {
            close(fileDescriptor)
        }
    }

    // MARK: - Connection

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
        portName = ""
        print("[serial] Disconnected")
    }

    // MARK: - Discovery

    private func findTeensyPort() -> String? {
        let fileManager = FileManager.default
        do {
            let devContents = try fileManager.contentsOfDirectory(atPath: "/dev")
            // Look for Teensy USB modem ports
            let candidates = devContents.filter { name in
                name.hasPrefix("tty.usbmodem") || name.hasPrefix("cu.usbmodem")
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
        portName = path
        print("[serial] Connected to \(path)")
        startReading()
    }

    // MARK: - Send

    /// Send evaluation scores to Teensy.
    /// Protocol: {U|C},creativity,soundness,ambition,elegance,risk\n
    func sendScores(_ scores: EvalScores, source: String) {
        guard fileDescriptor >= 0 else { return }

        let srcChar = source == "user" ? "U" : "C"
        let msg = String(format: "%@,%.2f,%.2f,%.2f,%.2f,%.2f\n",
                         srcChar,
                         scores.creativity,
                         scores.soundness,
                         scores.ambition,
                         scores.elegance,
                         scores.risk)

        let data = Array(msg.utf8)
        let written = data.withUnsafeBufferPointer { ptr in
            write(fileDescriptor, ptr.baseAddress, data.count)
        }

        if written < 0 {
            print("[serial] Write failed, reconnecting...")
            disconnect()
        }
    }

    /// Send a raw command string.
    func sendCommand(_ cmd: String) {
        guard fileDescriptor >= 0 else { return }
        let msg = cmd + "\n"
        let data = Array(msg.utf8)
        data.withUnsafeBufferPointer { ptr in
            _ = write(fileDescriptor, ptr.baseAddress, data.count)
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

                    // Process complete lines
                    while let newlineRange = lineBuffer.range(of: "\n") {
                        let line = String(lineBuffer[lineBuffer.startIndex..<newlineRange.lowerBound])
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        lineBuffer = String(lineBuffer[newlineRange.upperBound...])

                        if !line.isEmpty {
                            await MainActor.run {
                                self?.onLineReceived?(line)
                            }
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

    // MARK: - Reconnect

    private func startReconnectLoop() {
        reconnectTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3s
                if !isConnected {
                    connect()
                }
            }
        }
    }
}
