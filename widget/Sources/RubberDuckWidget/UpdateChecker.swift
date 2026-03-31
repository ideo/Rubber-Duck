// Update Checker — Polls GitHub Releases API to detect new app versions.
//
// Zero dependencies. Uses URLSession.shared (same as eval APIs).
// Checks on launch (30s delay) then every 12 hours while running.
// Publishes results via callbacks — menus and TTS wire in at startup.

import Foundation

@MainActor
final class UpdateChecker {
    private static let releasesURL = "https://api.github.com/repos/ideo/Rubber-Duck/releases/latest"
    private static let checkInterval: TimeInterval = 12 * 60 * 60  // 12 hours
    private static let initialDelay: TimeInterval = 30

    struct ReleaseInfo {
        let version: String       // e.g. "0.8.5"
        let tagName: String       // e.g. "v0.8.5"
        let htmlURL: String       // releases page
        let dmgURL: String?       // direct DMG download from assets
        let releaseNotes: String  // body text
    }

    // Published state — read by menus
    private(set) var latestRelease: ReleaseInfo?
    private(set) var isUpdateAvailable = false
    private(set) var isPluginStale = false

    // Callbacks wired by the app at startup
    var onUpdateDetected: ((ReleaseInfo) -> Void)?
    var onPluginStale: (() -> Void)?

    private var hasSpokeThisLaunch = false
    private var timer: Timer?

    // MARK: - Lifecycle

    func startPeriodicChecks() {
        // Initial check after a delay so we don't compete with mic/server/TTS startup
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.initialDelay) { [weak self] in
            Task { await self?.checkForUpdate() }
            self?.scheduleTimer()
        }
    }

    func stopPeriodicChecks() {
        timer?.invalidate()
        timer = nil
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            Task { await self?.checkForUpdate() }
        }
    }

    // MARK: - App Version Change Detection

    /// Call on launch to detect if the app was just updated.
    /// Returns true if the running version differs from the last-run version.
    func detectAppVersionChange() -> Bool {
        let current = Self.runningVersion
        let last = DuckConfig.lastRunAppVersion
        DuckConfig.lastRunAppVersion = current
        guard let last, last != current else { return false }
        DuckLog.log("[update] App version changed: \(last) → \(current)")
        return true
    }

    /// Check if the bundled plugin is newer than what was last installed.
    func detectPluginStaleness() {
        let bundled = Self.bundledPluginVersion
        let installed = DuckConfig.lastInstalledPluginVersion
        if let installed, bundled > installed {
            DuckLog.log("[update] Plugin stale: installed=\(installed) bundled=\(bundled)")
            isPluginStale = true
            onPluginStale?()
        }
    }

    /// Mark the current bundled plugin version as installed.
    static func recordPluginInstalled() {
        DuckConfig.lastInstalledPluginVersion = bundledPluginVersion
        DuckLog.log("[update] Recorded installed plugin version: \(bundledPluginVersion)")
    }

    /// Check if a remotely-reported plugin version is stale vs the bundled version.
    func checkRemotePluginVersion(_ reportedVersion: Int) {
        let bundled = Self.bundledPluginVersion
        if reportedVersion < bundled {
            DuckLog.log("[update] Remote plugin stale: reported=\(reportedVersion) bundled=\(bundled)")
            isPluginStale = true
            onPluginStale?()
        } else {
            isPluginStale = false
        }
    }

    // MARK: - GitHub API

    func checkForUpdate() async {
        // Rate limit: skip if checked recently
        if let last = DuckConfig.lastUpdateCheckTimestamp,
           Date().timeIntervalSince1970 - last < Self.checkInterval - 60 {
            return
        }

        DuckLog.log("[update] Checking GitHub for new release...")
        DuckConfig.lastUpdateCheckTimestamp = Date().timeIntervalSince1970

        guard let url = URL(string: Self.releasesURL) else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("DuckDuckDuck/\(Self.runningVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                DuckLog.log("[update] GitHub API returned non-200")
                return
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DuckLog.log("[update] Failed to parse GitHub response")
                return
            }

            guard let tagName = json["tag_name"] as? String else { return }
            let htmlURL = json["html_url"] as? String ?? "https://github.com/ideo/Rubber-Duck/releases"
            let body = json["body"] as? String ?? ""

            // Find DMG asset
            let assets = json["assets"] as? [[String: Any]] ?? []
            let dmgURL = assets.first(where: {
                ($0["name"] as? String ?? "").hasSuffix(".dmg")
            })?["browser_download_url"] as? String

            let version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
            let release = ReleaseInfo(
                version: version,
                tagName: tagName,
                htmlURL: htmlURL,
                dmgURL: dmgURL,
                releaseNotes: body
            )

            let running = Self.parseVersion(Self.runningVersion)
            let latest = Self.parseVersion(version)

            if Self.compareVersions(latest, running) == .orderedDescending {
                DuckLog.log("[update] New version available: \(version) (running \(Self.runningVersion))")
                latestRelease = release
                isUpdateAvailable = true

                if !hasSpokeThisLaunch {
                    hasSpokeThisLaunch = true
                    onUpdateDetected?(release)
                }
            } else {
                DuckLog.log("[update] Up to date (\(Self.runningVersion))")
                isUpdateAvailable = false
                latestRelease = nil
            }
        } catch {
            DuckLog.log("[update] GitHub check failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Version Utilities

    static var runningVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    static var bundledPluginVersion: Int {
        guard let pluginDir = Bundle.main.resourceURL?.appendingPathComponent("plugin"),
              let data = try? Data(contentsOf: pluginDir
                  .appendingPathComponent(".claude-plugin")
                  .appendingPathComponent("plugin.json")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let vStr = json["version"] as? String,
              let v = Int(vStr) else {
            return 0
        }
        return v
    }

    static func parseVersion(_ string: String) -> [Int] {
        string.components(separatedBy: ".").compactMap { Int($0) }
    }

    static func compareVersions(_ a: [Int], _ b: [Int]) -> ComparisonResult {
        let maxLen = max(a.count, b.count)
        for i in 0..<maxLen {
            let va = i < a.count ? a[i] : 0
            let vb = i < b.count ? b[i] : 0
            if va > vb { return .orderedDescending }
            if va < vb { return .orderedAscending }
        }
        return .orderedSame
    }
}
