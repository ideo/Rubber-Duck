// Duck Log — Unified logging to Application Support/DuckDuckDuck/DuckDuckDuck.log
//
// All components (server, evaluator, permission, etc.) log through this
// so you can watch everything with: tail -f ~/Library/Application\ Support/DuckDuckDuck/DuckDuckDuck.log

import Foundation

enum DuckLog {
    private static let logURL: URL = {
        DuckConfig.storageDir.appendingPathComponent("DuckDuckDuck.log")
    }()

    /// Thread-safe cached date formatter (ISO8601DateFormatter is not thread-safe,
    /// so we use a POSIX DateFormatter with a fixed format instead).
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    /// Serial queue to protect file writes and formatter access.
    private static let queue = DispatchQueue(label: "com.duckduckduck.log")

    /// Log a message to both stdout and the log file.
    static func log(_ msg: String) {
        queue.async {
            let ts = dateFormatter.string(from: Date())
            let line = "[\(ts)] \(msg)\n"
            print(line, terminator: "")
            if let data = line.data(using: .utf8) {
                // Try append first; create file if it doesn't exist yet
                if let handle = try? FileHandle(forWritingTo: logURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                } else {
                    try? data.write(to: logURL)
                }
            }
        }
    }
}
