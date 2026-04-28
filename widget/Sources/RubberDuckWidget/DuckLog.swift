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
    ///
    /// Uses the modern throwing Swift FileHandle API (`write(contentsOf:)`,
    /// `seekToEnd()`, `close()`). The legacy `write(_:)` raised uncatchable
    /// NSExceptions on I/O errors (disk full, file unlinked under us) which
    /// killed the whole process via `_objc_terminate` — a real crash hit when
    /// the serial port flooded the log during a non-duck Arduino device plug.
    /// Now any I/O error just drops the line and returns.
    static func log(_ msg: String) {
        queue.async {
            let ts = dateFormatter.string(from: Date())
            let line = "[\(ts)] \(msg)\n"
            print(line, terminator: "")
            guard let data = line.data(using: .utf8) else { return }

            do {
                // Try append; create file if it doesn't exist yet
                if let handle = try? FileHandle(forWritingTo: logURL) {
                    defer { try? handle.close() }
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                } else {
                    try data.write(to: logURL)
                }
            } catch {
                // Drop the log line silently — no point recursing into log()
                // from inside log()'s own failure path.
            }
        }
    }
}
