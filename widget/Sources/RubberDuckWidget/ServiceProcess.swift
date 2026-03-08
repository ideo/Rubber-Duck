// Service Process — Manages the Python eval service lifecycle.
//
// Auto-launches service/server.py when the widget starts.
// Kills it when the widget quits. Monitors health via /health endpoint.

import Foundation

@MainActor
class ServiceProcess: ObservableObject {
    @Published var isRunning: Bool = false
    @Published var lastError: String = ""

    private var process: Process?
    private var healthTask: Task<Void, Never>?
    private let port: Int = 3333

    var serviceURL: URL {
        URL(string: "http://localhost:\(port)")!
    }

    init() {
        startService()
        startHealthMonitor()
    }

    deinit {
        process?.terminate()
    }

    // MARK: - Service Discovery

    /// Find the repo root by walking up from the running binary.
    /// Binary is at: {repo}/widget/.build/{config}/RubberDuckWidget.app/Contents/MacOS/RubberDuckWidget
    /// Or: {repo}/widget/.build/{config}/RubberDuckWidget
    private func findRepoRoot() -> URL? {
        let bundle = Bundle.main.bundleURL

        // Walk up looking for service/server.py
        var dir = bundle
        for _ in 0..<10 {
            dir = dir.deletingLastPathComponent()
            let serverPath = dir.appendingPathComponent("service/server.py")
            if FileManager.default.fileExists(atPath: serverPath.path) {
                return dir
            }
        }

        // Also check common development paths
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent("Documents/GitHub/Rubber-Duck"),
            home.appendingPathComponent("Developer/Rubber-Duck"),
            home.appendingPathComponent("Projects/Rubber-Duck"),
        ]

        for candidate in candidates {
            let serverPath = candidate.appendingPathComponent("service/server.py")
            if FileManager.default.fileExists(atPath: serverPath.path) {
                return candidate
            }
        }

        return nil
    }

    // MARK: - Lifecycle

    func startService() {
        // Check if service is already running
        let alreadyRunning = checkHealth()
        if alreadyRunning {
            print("[service] Already running on port \(port)")
            isRunning = true
            return
        }

        guard let repoRoot = findRepoRoot() else {
            lastError = "Can't find Rubber Duck repo (service/server.py)"
            print("[service] \(lastError)")
            return
        }

        let serverScript = repoRoot.appendingPathComponent("service/server.py")
        let serviceDir = repoRoot.appendingPathComponent("service")
        let venvPython = serviceDir.appendingPathComponent("venv/bin/python")

        // Use venv python if it exists, otherwise system python3
        let pythonPath: String
        if FileManager.default.fileExists(atPath: venvPython.path) {
            pythonPath = venvPython.path
        } else {
            pythonPath = "/usr/bin/python3"
        }

        print("[service] Starting: \(pythonPath) \(serverScript.path)")

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: pythonPath)
        proc.arguments = [serverScript.path]
        proc.currentDirectoryURL = serviceDir
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice

        // Pass through environment (for ANTHROPIC_API_KEY from .env)
        var env = ProcessInfo.processInfo.environment
        // Also load from .env file manually if key is missing
        if env["ANTHROPIC_API_KEY"] == nil {
            let dotenv = serviceDir.appendingPathComponent(".env")
            if let contents = try? String(contentsOf: dotenv, encoding: .utf8) {
                for line in contents.components(separatedBy: .newlines) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
                    let parts = trimmed.components(separatedBy: "=")
                    if parts.count >= 2 {
                        let key = parts[0].trimmingCharacters(in: .whitespaces)
                        let value = parts.dropFirst().joined(separator: "=")
                            .trimmingCharacters(in: .whitespaces)
                            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                        env[key] = value
                    }
                }
            }
        }
        proc.environment = env

        do {
            try proc.run()
            process = proc
            print("[service] Started (PID \(proc.processIdentifier))")

            // Wait a moment then check health
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if checkHealth() {
                    isRunning = true
                    print("[service] Healthy")
                } else {
                    lastError = "Service started but not responding"
                    print("[service] \(lastError)")
                }
            }
        } catch {
            lastError = "Failed to start service: \(error.localizedDescription)"
            print("[service] \(lastError)")
        }
    }

    func stopService() {
        process?.terminate()
        process = nil
        isRunning = false
        print("[service] Stopped")
    }

    // MARK: - Claude Terminal Session

    /// Launch Claude Code in Terminal.app inside a tmux session named "duck".
    /// Uses tmux -A to attach if it already exists.
    func startClaudeSession() {
        guard let repoRoot = findRepoRoot() else {
            lastError = "Can't find repo root for Claude session"
            return
        }

        let script = """
        tell application "Terminal"
            activate
            do script "cd \(repoRoot.path) && if ! tmux has-session -t duck 2>/dev/null; then tmux new-session -d -s duck -n claude 'claude'; fi && tmux set-option -t duck -w allow-rename off 2>/dev/null && tmux rename-window -t duck claude 2>/dev/null && tmux attach -t duck"
        end tell
        """

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
            print("[service] Launched Claude terminal session")
        } catch {
            lastError = "Failed to launch Claude session: \(error.localizedDescription)"
            print("[service] \(lastError)")
        }
    }

    // MARK: - Health Check

    private nonisolated func checkHealth() -> Bool {
        let url = URL(string: "http://localhost:3333/health")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0

        let semaphore = DispatchSemaphore(value: 0)
        var healthy = false

        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                healthy = true
            }
            semaphore.signal()
        }.resume()

        semaphore.wait()
        return healthy
    }

    private func startHealthMonitor() {
        healthTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5s
                let healthy = checkHealth()
                if !healthy && isRunning {
                    isRunning = false
                    print("[service] Lost connection, restarting...")
                    startService()
                } else if healthy && !isRunning {
                    isRunning = true
                }
            }
        }
    }
}
