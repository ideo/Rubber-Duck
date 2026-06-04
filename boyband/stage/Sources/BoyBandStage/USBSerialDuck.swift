// USBSerialDuck — wired Stage transport for boy-band ducks.
//
// This is deliberately parallel to the WebSocket transport rather than a
// replacement. The show can opt into USB with --usb-map/--transport usb while
// the WiFi WebSocket path stays available for fallback testing.

import Foundation
import Darwin
import Dispatch

enum AudioTransportMode: String, Sendable {
    case ws
    case usb
    case auto

    static func parse(_ s: String) -> AudioTransportMode? {
        AudioTransportMode(rawValue: s.lowercased())
    }
}

struct USBDuckMapEntry: Sendable {
    let duck: DuckID
    let name: String?
    let duckID: String?
    let usbSerial: String?
    let currentDevice: String?
    let locationID: Int?
}

struct USBDuckMap: Sendable {
    let entries: [DuckID: USBDuckMapEntry]

    static func load(from path: String) -> USBDuckMap? {
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ducks = raw["ducks"] as? [[String: Any]] else {
            fputs("[usb-map] \(path): expected {\"ducks\":[...]}\n", stderr)
            return nil
        }

        var parsed: [DuckID: USBDuckMapEntry] = [:]
        for obj in ducks {
            guard let slot = obj["slot"] as? String,
                  let duck = DuckID.parse(slot) else {
                fputs("[usb-map] \(path): entry missing valid slot D1..D4 — skipped\n", stderr)
                continue
            }
            let locationID: Int?
            if let n = obj["location_id"] as? NSNumber {
                locationID = n.intValue
            } else {
                locationID = nil
            }
            parsed[duck] = USBDuckMapEntry(
                duck: duck,
                name: obj["name"] as? String,
                duckID: obj["duck_id"] as? String,
                usbSerial: obj["usb_serial"] as? String,
                currentDevice: obj["current_device"] as? String,
                locationID: locationID
            )
        }
        return USBDuckMap(entries: parsed)
    }

    var allEntries: [USBDuckMapEntry] {
        entries.values.sorted { $0.duck.rawValue < $1.duck.rawValue }
    }

    func name(for duck: DuckID) -> String? {
        entries[duck]?.name
    }
}

final class USBStage: @unchecked Sendable {
    private let map: USBDuckMap
    private let logger: @Sendable (String) -> Void
    private let lock = NSLock()
    private var ducks: [DuckID: USBSerialDuck] = [:]

    init(map: USBDuckMap, logger: @escaping @Sendable (String) -> Void) {
        self.map = map
        self.logger = logger
    }

    func start() {
        for entry in map.allEntries {
            guard let path = USBDeviceResolver.resolve(entry: entry) else {
                logger("usb        \(entry.duck.rawValue) no serial device found")
                continue
            }
            do {
                let conn = try USBSerialDuck(duck: entry.duck, path: path)
                lock.lock()
                ducks[entry.duck] = conn
                lock.unlock()
                let nm = entry.name.map { " (\($0))" } ?? ""
                logger("usb        \(entry.duck.rawValue)\(nm) opened \(path)")
            } catch {
                logger("usb        \(entry.duck.rawValue) \(path) open failed: \(error.localizedDescription)")
            }
        }
    }

    func stop() {
        lock.lock()
        let snapshot = Array(ducks.values)
        ducks.removeAll()
        lock.unlock()
        snapshot.forEach { $0.close() }
    }

    func isConnected(_ duck: DuckID) -> Bool {
        lock.lock()
        let conn = ducks[duck]
        lock.unlock()
        return conn?.isOpen ?? false
    }

    func sendPCM(_ duck: DuckID, _ pcm: Data) {
        lock.lock()
        let conn = ducks[duck]
        lock.unlock()
        conn?.sendPCM(pcm)
    }

    func reset(_ duck: DuckID) {
        lock.lock()
        let conn = ducks[duck]
        lock.unlock()
        conn?.sendReset()
    }

    func kick(_ duck: DuckID) -> Bool {
        reset(duck)
        return isConnected(duck)
    }

    func stats(for duck: DuckID) -> USBSerialDuck.SendStats? {
        lock.lock()
        let conn = ducks[duck]
        lock.unlock()
        return conn?.stats()
    }

    func statusReport() -> String {
        lock.lock()
        let snapshot = ducks.values.sorted { $0.duck.rawValue < $1.duck.rawValue }
        lock.unlock()

        if snapshot.isEmpty { return "connected: none\n" }

        var lines = ["connected: \(snapshot.map { $0.duck.rawValue }.joined(separator: ","))"]
        for conn in snapshot {
            let s = conn.stats()
            lines.append(String(format:
                "%@: health=ok transport=usb sent=%d/%@ completed=%d/%@ inFlight=%d/%@ maxInFlight=%@ dropped=%d/%@ lastWrite=%.1fms maxWrite=%.1fms device=%@",
                conn.duck.rawValue,
                s.sentFrames, StageServer.formatBytesForLog(s.sentBytes),
                s.completedFrames, StageServer.formatBytesForLog(s.completedBytes),
                s.inFlightFrames, StageServer.formatBytesForLog(s.inFlightBytes),
                StageServer.formatBytesForLog(s.maxInFlightBytesSeen),
                s.droppedFrames, StageServer.formatBytesForLog(s.droppedBytes),
                s.lastWriteMs, s.maxWriteMs, conn.path))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    func healthReport() -> String {
        lock.lock()
        let snapshot = ducks.values.sorted { $0.duck.rawValue < $1.duck.rawValue }
        lock.unlock()

        if snapshot.isEmpty { return "connected: none\n" }
        var lines = ["connected: \(snapshot.map { $0.duck.rawValue }.joined(separator: ","))"]
        for conn in snapshot {
            lines.append("\(conn.duck.rawValue): ok usb")
        }
        return lines.joined(separator: "\n") + "\n"
    }
}

private enum USBDeviceResolver {
    static func resolve(entry: USBDuckMapEntry) -> String? {
        if let path = entry.currentDevice,
           FileManager.default.fileExists(atPath: path) {
            return path
        }
        if let serial = entry.usbSerial,
           let loc = locationIDForUSBSerial(serial),
           let path = pathForLocationID(loc),
           FileManager.default.fileExists(atPath: path) {
            return path
        }
        if let loc = entry.locationID,
           let path = pathForLocationID(loc),
           FileManager.default.fileExists(atPath: path) {
            return path
        }
        return nil
    }

    private static func pathForLocationID(_ locationID: Int) -> String? {
        let hex = String(locationID >> 16, radix: 16)
        for suffix in [hex + "01", hex + "101", hex + "1"] {
            let path = "/dev/cu.usbmodem\(suffix)"
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }

    private static func locationIDForUSBSerial(_ serial: String) -> Int? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        p.arguments = ["-p", "IOUSB", "-w0", "-l"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do {
            try p.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { return nil }
        guard let text = String(data: data, encoding: .utf8) else { return nil }

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var currentSerial: String?
        var currentLocation: Int?
        func normalized(_ s: String) -> String {
            s.uppercased().filter { $0.isHexDigit }
        }

        for line in lines {
            if line.contains("USB JTAG/serial debug unit@") {
                currentSerial = nil
                currentLocation = nil
            }
            if let value = quotedValue(in: line, key: "USB Serial Number") ??
                           quotedValue(in: line, key: "kUSBSerialNumberString") {
                currentSerial = value
            }
            if let loc = intValue(in: line, key: "locationID") {
                currentLocation = loc
            }
            if let currentSerial,
               normalized(currentSerial) == normalized(serial),
               let currentLocation {
                return currentLocation
            }
        }
        return nil
    }

    private static func quotedValue(in line: String, key: String) -> String? {
        guard line.contains("\"\(key)\"") else { return nil }
        let parts = line.split(separator: "\"", omittingEmptySubsequences: false)
        guard parts.count >= 4 else { return nil }
        return String(parts[3])
    }

    private static func intValue(in line: String, key: String) -> Int? {
        guard line.contains("\"\(key)\"") else { return nil }
        guard let eq = line.firstIndex(of: "=") else { return nil }
        return Int(line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces))
    }
}

final class USBSerialDuck: @unchecked Sendable {
    let duck: DuckID
    let path: String
    private let fd: Int32
    private let queue: DispatchQueue
    private var readSource: DispatchSourceRead?
    private var readBuffer = Data()
    private var openFlag = true
    private var inFlightFrames = 0
    private var inFlightBytes = 0
    private var sentFrames = 0
    private var sentBytes = 0
    private var completedFrames = 0
    private var completedBytes = 0
    private var droppedFrames = 0
    private var droppedBytes = 0
    private var maxInFlightBytesSeen = 0
    private var lastWriteMs = 0.0
    private var maxWriteMs = 0.0

    init(duck: DuckID, path: String) throws {
        self.duck = duck
        self.path = path
        self.queue = DispatchQueue(label: "duck.usb.\(duck.rawValue)")
        let opened = Darwin.open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard opened >= 0 else {
            throw NSError(domain: "USBSerialDuck", code: Int(errno),
                          userInfo: [NSLocalizedDescriptionKey: String(cString: strerror(errno))])
        }
        self.fd = opened
        try Self.configureRaw(fd: opened)
        startReader()
    }

    var isOpen: Bool {
        queue.sync { openFlag }
    }

    func sendPCM(_ pcm: Data) {
        var frame = Data()
        frame.append(contentsOf: [0x44, 0x55, 0x4B, 0x31]) // "DUK1"
        frame.append(0x01)
        let len = UInt16(pcm.count)
        frame.append(UInt8(len & 0xFF))
        frame.append(UInt8((len >> 8) & 0xFF))
        frame.append(pcm)
        enqueueFrame(frame, pcmBytes: pcm.count)
    }

    func sendReset() {
        enqueueFrame(Data([0x44, 0x55, 0x4B, 0x31, 0x02, 0x00, 0x00]), pcmBytes: 0)
    }

    private func enqueueFrame(_ frame: Data, pcmBytes: Int) {
        queue.async {
            guard self.openFlag else { return }
            self.inFlightFrames += 1
            self.inFlightBytes += pcmBytes
            self.sentFrames += 1
            self.sentBytes += pcmBytes
            self.maxInFlightBytesSeen = max(self.maxInFlightBytesSeen, self.inFlightBytes)
            let started = DispatchTime.now().uptimeNanoseconds
            let ok = Self.writeAll(fd: self.fd, data: frame)
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000.0
            self.lastWriteMs = elapsed
            self.maxWriteMs = max(self.maxWriteMs, elapsed)
            self.inFlightFrames = max(self.inFlightFrames - 1, 0)
            self.inFlightBytes = max(self.inFlightBytes - pcmBytes, 0)
            if ok {
                self.completedFrames += 1
                self.completedBytes += pcmBytes
            } else {
                self.droppedFrames += 1
                self.droppedBytes += pcmBytes
                self.openFlag = false
                Darwin.close(self.fd)
            }
        }
    }

    func close() {
        queue.sync {
            if openFlag {
                readSource?.cancel()
                readSource = nil
                openFlag = false
                Darwin.close(fd)
            }
        }
    }

    struct SendStats: Sendable {
        let sentFrames: Int
        let sentBytes: Int
        let completedFrames: Int
        let completedBytes: Int
        let inFlightFrames: Int
        let inFlightBytes: Int
        let maxInFlightBytesSeen: Int
        let droppedFrames: Int
        let droppedBytes: Int
        let lastWriteMs: Double
        let maxWriteMs: Double
    }

    func stats() -> SendStats {
        queue.sync {
            SendStats(sentFrames: sentFrames,
                      sentBytes: sentBytes,
                      completedFrames: completedFrames,
                      completedBytes: completedBytes,
                      inFlightFrames: inFlightFrames,
                      inFlightBytes: inFlightBytes,
                      maxInFlightBytesSeen: maxInFlightBytesSeen,
                      droppedFrames: droppedFrames,
                      droppedBytes: droppedBytes,
                      lastWriteMs: lastWriteMs,
                      maxWriteMs: maxWriteMs)
        }
    }

    private static func configureRaw(fd: Int32) throws {
        var tio = termios()
        guard tcgetattr(fd, &tio) == 0 else {
            throw NSError(domain: "USBSerialDuck", code: Int(errno),
                          userInfo: [NSLocalizedDescriptionKey: "tcgetattr: \(String(cString: strerror(errno)))"])
        }
        cfmakeraw(&tio)
        _ = cfsetispeed(&tio, speed_t(B115200))
        _ = cfsetospeed(&tio, speed_t(B115200))
        tio.c_cflag |= tcflag_t(CLOCAL | CREAD)
        tio.c_cflag &= ~tcflag_t(HUPCL)
        guard tcsetattr(fd, TCSANOW, &tio) == 0 else {
            throw NSError(domain: "USBSerialDuck", code: Int(errno),
                          userInfo: [NSLocalizedDescriptionKey: "tcsetattr: \(String(cString: strerror(errno)))"])
        }
        let flags = fcntl(fd, F_GETFL, 0)
        if flags >= 0 {
            _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)
        }
        tcflush(fd, TCIOFLUSH)
    }

    private static func writeAll(fd: Int32, data: Data) -> Bool {
        data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return true }
            var offset = 0
            let deadline = Date().addingTimeInterval(0.25)
            while offset < data.count {
                let n = Darwin.write(fd, base.advanced(by: offset), data.count - offset)
                if n > 0 {
                    offset += n
                    continue
                }
                if n == 0 { return false }
                if errno == EINTR { continue }
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    if Date() > deadline { return false }
                    usleep(1000)
                    continue
                }
                return false
            }
            return true
        }
    }

    private func startReader() {
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in
            self?.drainRead()
        }
        source.setCancelHandler {}
        readSource = source
        source.resume()
    }

    private func drainRead() {
        var buf = [UInt8](repeating: 0, count: 512)
        while true {
            let n = Darwin.read(fd, &buf, buf.count)
            if n > 0 {
                readBuffer.append(contentsOf: buf[0..<n])
                emitCompleteLines()
                continue
            }
            if n == 0 { return }
            if errno == EINTR { continue }
            if errno == EAGAIN || errno == EWOULDBLOCK { return }
            return
        }
    }

    private func emitCompleteLines() {
        while let nl = readBuffer.firstIndex(of: 0x0A) {
            let lineData = readBuffer[..<nl]
            readBuffer.removeSubrange(...nl)
            guard let line = String(data: lineData, encoding: .utf8),
                  line.hasPrefix("DUKSTAT ") else {
                continue
            }
            print("[usb \(duck.rawValue)] \(line)")
        }
        if readBuffer.count > 4096 {
            readBuffer.removeAll(keepingCapacity: true)
        }
    }
}
