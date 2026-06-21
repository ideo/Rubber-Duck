// Cursor Activity Monitor — derives "Cursor is parked waiting for the user to
// approve a command" and chirps once, WITHOUT influencing Cursor's decision.
//
// Cursor never tells a hook whether a command will require approval — the hook
// path and Cursor's own approval path are separate, and beforeShellExecution
// fires identically for auto-run and prompt-me commands. So we derive it from
// timing: a command that's still unresolved a couple seconds after its
// beforeShellExecution is one Cursor is sitting on, waiting for the user.
//
//   on-permission.sh   (beforeShellExecution) → POST /activity {state:"pending"}
//   on-after-shell.sh  (afterShellExecution)  → POST /activity {state:"resolved"}
//
// pending arms a self-cleaning timer; resolved cancels it. Timer survives →
// chirp. Auto-approved commands resolve in milliseconds → silent.
//
// Hardened against the real failure modes (see the design review):
//  - Order-tolerant: MiniServer spawns an independent Task per request with NO
//    ordering guarantee, so "resolved" can land before "pending". resolvedEarly
//    absorbs that.
//  - Self-cleaning: a fired timer removes its own entry, so a DENIED/cancelled
//    command (whose afterShellExecution never fires) can't leak an entry.
//  - MainActor + DispatchWorkItem timer (the proven thinkingTimeout pattern) —
//    a bare Timer on the server's GCD queue would silently never fire.
//  - Per-repo cooldown + coalescing so rapid commands chirp at most once.
//  - MCP pendings are recorded as no-ops (no afterMCPExecution resolve signal is
//    confirmed yet, so arming a timer would guarantee false alarms).

import Foundation

@MainActor
final class CursorActivityMonitor {
    /// How long a command may stay unresolved before we treat Cursor as parked
    /// on its approve prompt. Tuned above typical auto-run latency so a fast
    /// allow-listed command is clearly excluded.
    private let parkedThreshold: TimeInterval = 2.5
    /// Don't re-chirp for the same repo more often than this.
    private let repoCooldown: TimeInterval = 30
    /// Drop resolvedEarly markers older than this (bounds the set).
    private let resolvedEarlyTTL: TimeInterval = 10
    /// Hard cap on live pending entries (runaway backstop).
    private let maxPending = 32

    private struct Pending {
        let work: DispatchWorkItem
        let repo: String
        let app: String
        let at: Date
    }

    private var pending: [String: Pending] = [:]
    private var resolvedEarly: [String: Date] = [:]
    private var lastChirpByRepo: [String: Date] = [:]

    /// Set by the app: speaks a single short ambient line (drops if busy).
    var onChirp: ((String) -> Void)?

    // MARK: - Hook events (called on MainActor from the /activity handler)

    /// A command is about to run. shell → arm the parked-timer; mcp → ignore
    /// (no confirmed resolve signal, so a timer would always false-fire).
    func handlePending(kind: String, conversationId: String, command: String, repo: String, app: String) {
        guard kind == "shell" else { return }
        let key = Self.key(conversationId, command)

        evictStaleResolvedEarly()

        // Already resolved before we registered (out-of-order race) → it ran
        // fast, nothing to announce.
        if let t = resolvedEarly[key], Date().timeIntervalSince(t) <= resolvedEarlyTTL {
            resolvedEarly.removeValue(forKey: key)
            return
        }
        // Idempotent: a duplicate pending for a live key must not re-arm.
        if pending[key] != nil { return }

        if pending.count >= maxPending { dropOldestPending() }

        let work = DispatchWorkItem { [weak self] in
            self?.fire(key: key, repo: repo, app: app)
        }
        pending[key] = Pending(work: work, repo: repo, app: app, at: Date())
        DispatchQueue.main.asyncAfter(deadline: .now() + parkedThreshold, execute: work)
    }

    /// A command actually ran (post-approval). Cancel its pending timer; if it
    /// arrives before the matching pending was registered, remember it briefly.
    func handleResolved(conversationId: String, command: String) {
        let key = Self.key(conversationId, command)
        if let p = pending.removeValue(forKey: key) {
            p.work.cancel()
        } else {
            evictStaleResolvedEarly()
            resolvedEarly[key] = Date()
        }
    }

    /// Cancel everything (app shutdown / server stop).
    func clearAll() {
        for p in pending.values { p.work.cancel() }
        pending.removeAll()
        resolvedEarly.removeAll()
        lastChirpByRepo.removeAll()
    }

    // MARK: - Internals

    private func fire(key: String, repo: String, app: String) {
        // Self-cleaning: remove our own entry whether or not we end up chirping.
        pending.removeValue(forKey: key)

        guard AppDelegate.isDuckActive else { return }

        // Per-repo cooldown so a burst of parked commands chirps once.
        let now = Date()
        if let last = lastChirpByRepo[repo], now.timeIntervalSince(last) < repoCooldown {
            return
        }
        lastChirpByRepo[repo] = now

        onChirp?(Self.message(app: app, repo: repo))
    }

    private func dropOldestPending() {
        guard let oldest = pending.min(by: { $0.value.at < $1.value.at }) else { return }
        oldest.value.work.cancel()
        pending.removeValue(forKey: oldest.key)
    }

    private func evictStaleResolvedEarly() {
        let now = Date()
        resolvedEarly = resolvedEarly.filter { now.timeIntervalSince($0.value) <= resolvedEarlyTTL }
    }

    /// Key on conversation_id + command — both events carry these, and there's
    /// no per-command id in Cursor's payloads. \u{1} can't appear in either part.
    private static func key(_ conversationId: String, _ command: String) -> String {
        conversationId + "\u{1}" + command
    }

    private static func displayName(_ app: String) -> String {
        switch app {
        case "cursor": return "Cursor"
        case "claude-code": return "Claude"
        default: return app.isEmpty ? "Your agent" : app
        }
    }

    /// app + repo only — never the command (privacy + length + no-spam tone).
    private static func message(app: String, repo: String) -> String {
        let name = displayName(app)
        return repo.isEmpty ? "\(name)'s waiting on you to approve something."
                            : "\(name)'s waiting on you in \(repo)."
    }
}
