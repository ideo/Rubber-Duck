// Firmware Updater — Detects when the plugged-in duck is running older
// firmware than what's published on Pages and surfaces a status-bar
// menu item to (currently) hand off to the web flasher. A future
// phase will bundle espflash to do the reflash in-app; today it just
// notices and points the user at https://ideo.github.io/Rubber-Duck/flash/.
//
// Why a separate service from UpdateChecker:
//   - UpdateChecker watches the WIDGET app (Mac binary) against GitHub
//     Releases; the user clicks → downloads a .dmg.
//   - FirmwareUpdater watches the DUCK (the ESP32 plugged into USB)
//     against docs/flash/firmware/cc-latest.json on Pages; the user
//     clicks → opens the web flasher.
// Different lifecycles (firmware bumps don't ship .dmg releases anymore
// and vice versa), different staleness signals (USB-serial handshake
// vs. running CFBundleShortVersionString), and the web-flasher hand-off
// is firmware-specific. Mixing them into UpdateChecker would tangle the
// menu logic and re-introduce the GitHub Releases coupling we just
// stripped out.
//
// Data flow:
//   1. SerialTransport.parseIdentity now captures the firmware version
//      from the DUCK,<chip>,<proto>,<variant>,<firmware_ver> handshake.
//   2. SerialTransport.onIdentity fires whenever a duck completes a
//      fresh handshake (boot or replug).
//   3. We re-check then; also periodic poll every 12h via timer (same
//      cadence as UpdateChecker so we're not chatty about it).
//   4. cc-latest.json fetched from Pages; small JSON, cached briefly.
//   5. Version compare (string equality is fine — tags are exact).
//   6. Publish isFirmwareUpdateAvailable; StatusBarManager reads it.

import Foundation

@MainActor
final class FirmwareUpdater {
    // Per-variant manifest URL on the Pages site. Bambu firmware will
    // get its own checker if/when we add an in-widget OTA story for it
    // (currently Bambu OTA happens on-device via the captive portal —
    // the widget never talks to a Bambu duck). For Claude Code Duck
    // there's one manifest covering both ducky PCB and XIAO variants.
    private static let manifestURL =
        "https://ideo.github.io/Rubber-Duck/flash/firmware/cc-latest.json"

    /// User-facing landing page for the flash hand-off. Phase 2 will
    /// replace clicking-here-opens-browser with an in-app sheet that
    /// drives espflash directly, but the URL stays valid as the
    /// "advanced / recovery" path.
    static let webFlasherURL = "https://ideo.github.io/Rubber-Duck/flash/"

    private static let checkInterval: TimeInterval = 12 * 60 * 60  // 12 hours
    private static let initialDelay: TimeInterval = 35  // after UpdateChecker's 30s

    struct LatestManifest {
        let version: String   // e.g. "cc-v0.1.4"
        let releasedAt: String

        /// Map from variant tag (matches SerialTransport.connectedVariant,
        /// e.g. "DUCKY_PCB" or "XIAO") to the same-origin download URL
        /// for that variant's .bin. Used by the phase-2 in-app flasher;
        /// phase 1 doesn't read it.
        let binaryURLByVariant: [String: String]
    }

    // Published state — read by StatusBarManager.
    private(set) var latestManifest: LatestManifest?
    private(set) var connectedFirmwareVersion: String?
    private(set) var isFirmwareUpdateAvailable = false

    // Callbacks wired at startup. onFirmwareStale fires once per fresh
    // detection so SpeechService can react if we ever want the duck to
    // mention it (we don't right now — quiet by design).
    var onFirmwareStale: ((LatestManifest, _ runningVersion: String) -> Void)?

    private var timer: Timer?
    private weak var serialTransport: SerialTransport?

    // MARK: - Lifecycle

    /// Plumb in the serial transport so we can read the duck's reported
    /// firmware version. Optional: if no duck is ever plugged in, we
    /// still poll the manifest but won't compare against anything.
    func bind(to transport: SerialTransport) {
        self.serialTransport = transport
        // Re-check whenever a duck completes a handshake. Replug, boot,
        // reflash via the web flasher — all trigger a fresh identity.
        transport.onIdentity = { [weak self] in
            Task { @MainActor in
                self?.handleNewIdentity()
            }
        }
    }

    func startPeriodicChecks() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.initialDelay) { [weak self] in
            Task { await self?.refreshManifest() }
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
            Task { await self?.refreshManifest() }
        }
    }

    // MARK: - Manifest fetch

    /// Force a re-check. Called when the Preferences pane appears so
    /// users staring at the firmware row see fresh data, not a stale
    /// 12-hour-old hit.
    func forceCheck() async {
        await refreshManifest()
    }

    private func refreshManifest() async {
        guard let url = URL(string: Self.manifestURL) else { return }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("DuckDuckDuck/\(UpdateChecker.runningVersion)",
                         forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                DuckLog.log("[firmware-updater] manifest fetch non-200")
                return
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let version = json["version"] as? String else {
                DuckLog.log("[firmware-updater] manifest parse failed")
                return
            }
            let releasedAt = json["released_at"] as? String ?? ""
            var byVariant: [String: String] = [:]
            if let variants = json["variants"] as? [String: Any] {
                for (key, value) in variants {
                    if let entry = value as? [String: Any],
                       let url = entry["url"] as? String {
                        // Manifest key is lowercase ("ducky" / "xiao");
                        // the chip's identity reply uses uppercase tags
                        // ("DUCKY_PCB" / "XIAO"). Store both lookups so
                        // either side can fetch without casing rules.
                        byVariant[key.uppercased()] = url
                        byVariant[key] = url
                    }
                }
            }
            // The manifest's "ducky" key needs a DUCKY_PCB alias since
            // that's what the chip reports — lowercase->uppercase above
            // gives us "DUCKY" but not "DUCKY_PCB". Add it explicitly.
            if let duckyURL = byVariant["ducky"] {
                byVariant["DUCKY_PCB"] = duckyURL
            }
            let manifest = LatestManifest(
                version: version,
                releasedAt: releasedAt,
                binaryURLByVariant: byVariant
            )
            self.latestManifest = manifest
            DuckLog.log("[firmware-updater] manifest latest=\(version)")
            recomputeStaleness()
        } catch {
            DuckLog.log("[firmware-updater] manifest fetch error: \(error.localizedDescription)")
        }
    }

    // MARK: - Staleness compute

    private func handleNewIdentity() {
        connectedFirmwareVersion = serialTransport?.connectedFirmwareVersion
        recomputeStaleness()
    }

    private func recomputeStaleness() {
        guard let manifest = latestManifest else {
            // No manifest yet — don't claim stale or fresh, just wait.
            isFirmwareUpdateAvailable = false
            return
        }
        guard let running = connectedFirmwareVersion ?? serialTransport?.connectedFirmwareVersion else {
            // No firmware version reported — could be old firmware that
            // pre-dates the FIRMWARE_VERSION stamp, or no duck plugged
            // in. Either way, can't compare → don't surface a prompt.
            // We don't want every unflashed/legacy duck to nag.
            isFirmwareUpdateAvailable = false
            return
        }
        connectedFirmwareVersion = running
        // Exact string compare. Tags are immutable and version-ordered
        // already (cc-v0.1.3 < cc-v0.1.4 alphabetically), but the more
        // important property here is "matches latest" vs "doesn't" —
        // we're not trying to gate on monotonicity. If a user is
        // running a pre-release built ad-hoc from a non-tag commit,
        // they'll see "update available" against the latest tag, which
        // is correct: they probably do want to know.
        let stale = running != manifest.version
        if stale && !isFirmwareUpdateAvailable {
            DuckLog.log("[firmware-updater] stale: running=\(running) latest=\(manifest.version)")
            onFirmwareStale?(manifest, running)
        }
        isFirmwareUpdateAvailable = stale
    }
}
