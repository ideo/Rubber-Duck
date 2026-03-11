// Duck Log — Unified logging to Application Support/DuckDuckDuck/DuckDuckDuck.log
//
// All components (server, evaluator, permission, etc.) log through this
// so you can watch everything with: tail -f ~/Library/Application\ Support/DuckDuckDuck/DuckDuckDuck.log

import Foundation

enum DuckLog {
    private static let logURL: URL = {
        DuckConfig.storageDir.appendingPathComponent("DuckDuckDuck.log")
    }()

    /// Log a message to both stdout and the log file.
    static func log(_ msg: String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        let line = "[\(ts)] \(msg)\n"
        print(line, terminator: "")
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logURL.path) {
                if let handle = try? FileHandle(forWritingTo: logURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: logURL)
            }
        }
    }
}
