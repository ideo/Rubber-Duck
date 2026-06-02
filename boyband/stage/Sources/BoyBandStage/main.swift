// Boy Band — Stage entry point.
//
// Headless CLI that:
//   1. Listens on ws://0.0.0.0:<port>, accepts WS upgrades on:
//        /ws/duck     (real firmware; slot from X-Duck-Id header via duck-map)
//        /duck/{ID}   (test/dev shortcut; slot from path, used by fake-duck.py)
//   2. Logs connect / disconnect / inbound text frames
//   3. Optionally streams a steady sine tone to every connected duck
//      (different pitch per duck so the channel routing is audible)
//
// Usage:
//   swift run BoyBandStage                       # server only, idle
//   swift run BoyBandStage --sine                # stream sine to all
//   swift run BoyBandStage --sine D2             # solo D2; others silent
//   swift run BoyBandStage --port 3334           # explicit port (default 3334)
//   swift run BoyBandStage --duck-map FILE.json  # MAC→slot map
//   swift run BoyBandStage --no-duck-map         # /duck/{ID} only (test mode)
//
// Default duck-map lookup order:
//   ./duck-map.local.json
//   <repo>/boyband/duck-map.local.json
//
// Point a duck's NVS relay_url at ws://<this-mac>.local:3334 to wire it in.
// See boyband/docs/duck-id-mapping.md for the MAC→slot config workflow.

import Foundation
import Dispatch

// MARK: - Args

struct Args {
    var port: UInt16 = 3334
    var sine: Bool = false
    var soloDuck: DuckID? = nil
    /// Explicit map path. nil = use defaults.
    var duckMapPath: String? = nil
    /// If true, don't load any map; /ws/duck connections will be rejected.
    var noDuckMap: Bool = false
    /// Mode 1: read multichannel input from a CoreAudio device.
    var mode1: Bool = false
    /// Substring of the input device name (default "BlackHole"). Ignored
    /// unless --mode1 is set.
    var inputDeviceMatch: String = "BlackHole"
    /// If true, just print all input devices and exit.
    var listInputs: Bool = false
    /// One or more (file → duck) pairs to stream. Repeatable --play lets
    /// us drive multiple ducks with DIFFERENT audio simultaneously — the
    /// core of the multi-duck concept test.
    var plays: [(path: String, duck: DuckID)] = []
    /// Loop the played file(s) instead of stopping after one pass.
    var loop: Bool = false
    /// Pre-load --play tracks but don't auto-start; wait for HTTP /play.
    /// Lets ducks connect+stabilize once, then trigger replays with no
    /// Stage restart (restarts churn duck connections and wedge them).
    var waitTrigger: Bool = false
    /// Preload a directory of chunk files named like NAME_part01_D1.wav.
    /// HTTP /next and /prev switch the active cue without restarting Stage.
    var playlistDir: String? = nil
}

func parseArgs() -> Args {
    var args = Args()
    var i = 1
    let argv = CommandLine.arguments
    while i < argv.count {
        let a = argv[i]
        switch a {
        case "--port":
            i += 1
            guard i < argv.count, let p = UInt16(argv[i]) else {
                fputs("error: --port requires a number\n", stderr); exit(2)
            }
            args.port = p
        case "--sine":
            args.sine = true
            // Optional next arg = solo duck. If next is a known DuckID, eat it.
            if i + 1 < argv.count, let d = DuckID.parse(argv[i + 1]) {
                args.soloDuck = d
                i += 1
            }
        case "--duck-map":
            i += 1
            guard i < argv.count else {
                fputs("error: --duck-map requires a path\n", stderr); exit(2)
            }
            args.duckMapPath = argv[i]
        case "--no-duck-map":
            args.noDuckMap = true
        case "--mode1":
            args.mode1 = true
        case "--input-device":
            i += 1
            guard i < argv.count else {
                fputs("error: --input-device requires a name substring\n", stderr)
                exit(2)
            }
            args.inputDeviceMatch = argv[i]
        case "--list-inputs":
            args.listInputs = true
        case "--play":
            i += 1
            guard i < argv.count else {
                fputs("error: --play requires a file path\n", stderr); exit(2)
            }
            let path = argv[i]
            // Optional next arg = target duck (default D1). Repeatable:
            // --play a.wav D1 --play b.wav D2 drives both at once.
            var duck = DuckID.D1
            if i + 1 < argv.count, let d = DuckID.parse(argv[i + 1]) {
                duck = d
                i += 1
            }
            args.plays.append((path: path, duck: duck))
        case "--loop":
            args.loop = true
        case "--wait-trigger":
            args.waitTrigger = true
        case "--playlist-dir":
            i += 1
            guard i < argv.count else {
                fputs("error: --playlist-dir requires a directory\n", stderr)
                exit(2)
            }
            args.playlistDir = argv[i]
        case "-h", "--help":
            printHelp(); exit(0)
        default:
            fputs("error: unknown arg \(a)\n", stderr)
            printHelp(); exit(2)
        }
        i += 1
    }
    if args.duckMapPath != nil && args.noDuckMap {
        fputs("error: --duck-map and --no-duck-map are mutually exclusive\n", stderr)
        exit(2)
    }
    if args.playlistDir != nil && !args.plays.isEmpty {
        fputs("error: --playlist-dir and --play are mutually exclusive\n", stderr)
        exit(2)
    }
    return args
}

func printHelp() {
    let help = """
    Boy Band — Stage server

    Usage:
      BoyBandStage [--port N] [--sine [DUCKID]]
                   [--duck-map FILE.json | --no-duck-map]
                   [--mode1 [--input-device SUBSTR]]
                   [--play FILE [DUCKID] [--loop]]
                   [--list-inputs]

    Options:
      --port N             Listen port (default 3334)
      --sine               Stream a steady sine to every connected duck
      --sine DUCKID        Solo one duck (D1..D4); others stay silent
      --duck-map FILE      Path to MAC→slot JSON map (used by /ws/duck)
      --no-duck-map        Disable /ws/duck; only test path /duck/{ID} works
      --mode1              Mode 1: read 4ch input from CoreAudio, route to ducks
      --input-device STR   Substring of input device name (default "BlackHole")
      --play FILE [DUCKID] Stream an audio file (wav/aiff/mp3/m4a) to one duck
                           (default D1). Resamples to 16k/mono/int16, paced.
      --playlist-dir DIR   Preload NAME_partNN_DX.wav chunks. /next and /prev
                           switch cues without restarting Stage.
      --loop               With --play: loop the file instead of one pass
      --list-inputs        Print available input devices and exit
      -h, --help           Show this help

    Routes:
      /ws/duck    + X-Duck-Id: <MAC>     real firmware path (needs duck-map)
      /duck/{ID}                          test/dev shortcut (no map needed)

    Default duck-map search order: ./duck-map.local.json,
    then <repo>/boyband/duck-map.local.json.
    """
    print(help)
}

/// Try the default map locations in order. Returns nil if none exist.
func defaultDuckMapPath() -> String? {
    let candidates = [
        "duck-map.local.json",
        "../duck-map.local.json",
        // Common case: invoked from inside boyband/stage/
        "../boyband/duck-map.local.json",
    ]
    let fm = FileManager.default
    for c in candidates {
        if fm.fileExists(atPath: c) { return c }
    }
    return nil
}

// MARK: - Logging

func log(_ s: String) {
    let ts = ISO8601DateFormatter().string(from: Date())
    print("[\(ts)] \(s)")
}

// MARK: - Main

let args = parseArgs()

// --list-inputs: print devices and exit. Does not start the server.
if args.listInputs {
    let devices = DAWInput.listInputDevices()
    if devices.isEmpty {
        print("(no input devices found)")
    } else {
        print("Available input devices:")
        for d in devices {
            print(String(format: "  %3dch  %@", d.channels, d.name))
        }
    }
    exit(0)
}

var sineGen: SineGenerator?  // set after server starts
var dawInput: DAWInput?      // set if Mode 1 enabled
var filePlayers: [FilePlayer] = []  // one per --play pair

struct LoadedTrack: @unchecked Sendable {
    let player: FilePlayer
    let duck: DuckID
    let path: String
    let durationSec: Double
}

struct LoadedCue: @unchecked Sendable {
    let part: Int
    let name: String
    let tracks: [LoadedTrack]
    let durationSec: Double
}

final class PlaylistState: @unchecked Sendable {
    private let lock = NSLock()
    private var index: Int = 0
    private var playing: Bool = false
    private var generation: Int = 0
    private var remainingTracks: Int = 0
    private var startedAt: Date?

    func currentIndex() -> Int {
        lock.lock(); defer { lock.unlock() }
        return index
    }

    func snapshot() -> (index: Int, playing: Bool, generation: Int, startedAt: Date?) {
        lock.lock(); defer { lock.unlock() }
        return (index, playing, generation, startedAt)
    }

    func advance(delta: Int, maxIndex: Int) -> Int {
        lock.lock(); defer { lock.unlock() }
        index = min(max(index + delta, 0), maxIndex)
        playing = false
        remainingTracks = 0
        startedAt = nil
        generation += 1
        return index
    }

    func start(trackCount: Int) -> Int {
        lock.lock(); defer { lock.unlock() }
        generation += 1
        remainingTracks = trackCount
        playing = trackCount > 0
        startedAt = playing ? Date() : nil
        return generation
    }

    func stop() {
        lock.lock(); defer { lock.unlock() }
        generation += 1
        remainingTracks = 0
        playing = false
        startedAt = nil
    }

    func finish(generation expectedGeneration: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard generation == expectedGeneration else { return false }
        remainingTracks = max(remainingTracks - 1, 0)
        guard remainingTracks == 0 else { return false }
        playing = false
        startedAt = nil
        return true
    }
}

final class RecoveryMonitor: @unchecked Sendable {
    private let lock = NSLock()
    private var timer: DispatchSourceTimer?

    func replace(with newTimer: DispatchSourceTimer) {
        lock.lock()
        let oldTimer = timer
        timer = newTimer
        lock.unlock()
        oldTimer?.cancel()
        newTimer.resume()
    }

    func cancel() {
        lock.lock()
        let oldTimer = timer
        timer = nil
        lock.unlock()
        oldTimer?.cancel()
    }
}

func jsonEscape(_ s: String) -> String {
    var out = ""
    for ch in s {
        switch ch {
        case "\\": out += "\\\\"
        case "\"": out += "\\\""
        case "\n": out += "\\n"
        case "\r": out += "\\r"
        case "\t": out += "\\t"
        default: out.append(ch)
        }
    }
    return out
}

// Resolve duck-map FIRST so the connect/disconnect logs can show names.
let duckMap: DuckMap? = {
    if args.noDuckMap { return nil }
    let path = args.duckMapPath ?? defaultDuckMapPath()
    guard let path else {
        log("duck-map    not found (production /ws/duck path disabled). " +
            "Use --duck-map FILE or --no-duck-map to silence this warning.")
        return nil
    }
    guard let map = DuckMap.load(from: path) else {
        fputs("fatal: --duck-map \(path) could not be loaded\n", stderr)
        exit(1)
    }
    let entries = map.allEntries
    log("duck-map    loaded \(path) — \(entries.count) entries")
    for e in entries {
        let nm = e.name.map { " \"\($0)\"" } ?? ""
        log("  \(e.duck.rawValue)\(nm) ← \(e.mac)")
    }
    return map
}()

// Label a connection as "D2 (Pekin)" when a name is known, else just "D2".
func label(_ duck: DuckID) -> String {
    if let n = duckMap?.name(for: duck) { return "\(duck.rawValue) (\(n))" }
    return duck.rawValue
}

let callbacks = StageCallbacks(
    onConnect: { conn in
        log("connect    \(label(conn.duck))  id=\(conn.id.uuidString.prefix(8))")
    },
    onDisconnect: { conn in
        log("disconnect \(label(conn.duck))  id=\(conn.id.uuidString.prefix(8))")
    },
    onText: { conn, text in
        log("text       \(label(conn.duck))  \(text)")
    },
    onBinary: { _, _ in
        // Duck mic frames are dropped — we use the Mac mic in Mode 2.
    }
)

let server = StageServer(port: args.port, duckMap: duckMap, callbacks: callbacks)

do {
    try server.start()
} catch {
    fputs("fatal: cannot bind port \(args.port): \(error)\n", stderr)
    exit(1)
}

if duckMap != nil {
    log("listening on ws://0.0.0.0:\(args.port)/ws/duck (prod) " +
        "and /duck/{D1..D4} (test)")
} else {
    log("listening on ws://0.0.0.0:\(args.port)/duck/{D1..D4} (test only)")
}

if args.sine {
    let gen = SineGenerator(server: server)
    gen.start(solo: args.soloDuck)
    sineGen = gen
    if let solo = args.soloDuck {
        log("sine        solo=\(solo.rawValue) (others silent)")
    } else {
        log("sine        broadcasting to all connected ducks")
    }
}

if args.mode1 {
    if args.sine {
        fputs("error: --mode1 and --sine are mutually exclusive\n", stderr)
        exit(2)
    }
    guard let devID = DAWInput.findDevice(matching: args.inputDeviceMatch,
                                          minChannels: 4) else {
        fputs("fatal: no input device matching '\(args.inputDeviceMatch)' with ≥4 channels\n",
              stderr)
        fputs("       run with --list-inputs to see what's available\n", stderr)
        exit(1)
    }
    let input = DAWInput(server: server)
    do {
        try input.start(deviceID: devID)
        dawInput = input
        log("mode1       reading 4ch input matching '\(args.inputDeviceMatch)' → D1..D4")
    } catch {
        fputs("fatal: mode1 start failed: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}

if let playlistDir = args.playlistDir {
    if args.sine || args.mode1 {
        fputs("error: --playlist-dir is mutually exclusive with --sine / --mode1\n",
              stderr)
        exit(2)
    }
    let dirURL = URL(fileURLWithPath: playlistDir)
    let fm = FileManager.default
    guard let files = try? fm.contentsOfDirectory(at: dirURL,
                                                  includingPropertiesForKeys: nil)
    else {
        fputs("fatal: --playlist-dir \(playlistDir) could not be read\n", stderr)
        exit(1)
    }

    var grouped: [Int: [(path: String, duck: DuckID)]] = [:]
    for url in files {
        let stem = url.deletingPathExtension().lastPathComponent
        guard let partRange = stem.range(of: "_part", options: .backwards) else {
            continue
        }
        let rest = stem[partRange.upperBound...].split(separator: "_", maxSplits: 1)
        guard rest.count == 2,
              let part = Int(rest[0]),
              let duck = DuckID.parse(String(rest[1])) else {
            continue
        }
        grouped[part, default: []].append((path: url.path, duck: duck))
    }

    let cues: [LoadedCue] = grouped.keys.sorted().map { part in
        let entries = grouped[part]!.sorted { $0.duck.rawValue < $1.duck.rawValue }
        let tracks: [LoadedTrack] = entries.map { entry in
            let player = FilePlayer(server: server, duck: entry.duck, loop: false)
            var durationSec = 0.0
            do {
                let dur = try player.load(path: entry.path)
                durationSec = dur
                log(String(format: "playlist   part%02d %@ → %@ (%.1fs)",
                           part,
                           (entry.path as NSString).lastPathComponent,
                           entry.duck.rawValue,
                           dur))
            } catch {
                fputs("fatal: playlist load \(entry.path) failed: \(error.localizedDescription)\n",
                      stderr)
                exit(1)
            }
            return LoadedTrack(player: player, duck: entry.duck, path: entry.path,
                               durationSec: durationSec)
        }
        let durationSec = tracks.map(\.durationSec).max() ?? 0
        return LoadedCue(part: part, name: String(format: "part%02d", part),
                         tracks: tracks, durationSec: durationSec)
    }

    if cues.isEmpty {
        fputs("fatal: --playlist-dir \(playlistDir) contained no NAME_partNN_DX audio files\n",
              stderr)
        exit(1)
    }

    filePlayers = cues.flatMap { $0.tracks.map(\.player) }
    let playlistState = PlaylistState()
    let recoveryMonitor = RecoveryMonitor()

    @Sendable func cueLine() -> String {
        let cueIndex = playlistState.currentIndex()
        let cue = cues[cueIndex]
        let targets = cue.tracks.map { label($0.duck) }.joined(separator: ", ")
        return "cue \(cueIndex + 1)/\(cues.count): \(cue.name) → \(targets)\n"
    }

    @Sendable func stopAllPlaylistTracks() {
        for cue in cues {
            for track in cue.tracks { track.player.stop() }
        }
        recoveryMonitor.cancel()
        playlistState.stop()
    }

    @Sendable func startRecoveryMonitor(generation: Int) {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now() + .seconds(1), repeating: .seconds(1))
        timer.setEventHandler {
            let snapshot = playlistState.snapshot()
            guard snapshot.playing, snapshot.generation == generation else { return }
            let kicked = server.kickWedgedConnections()
            if !kicked.isEmpty {
                let names = kicked.map { label($0) }.joined(separator: ", ")
                log("recover    kicked wedged \(names); waiting for reconnect")
            }
        }
        recoveryMonitor.replace(with: timer)
    }

    @Sendable func triggerCue(_ cue: LoadedCue) {
        let targets = cue.tracks.map { $0.duck }
        let names = targets.map { label($0) }.joined(separator: ", ")
        let present = targets.filter { server.connection(for: $0) != nil }.count
        log("playlist   ▶ \(cue.name) \(names)  (\(present)/\(targets.count) ducks connected)")
        let generation = playlistState.start(trackCount: cue.tracks.count)
        startRecoveryMonitor(generation: generation)
        for track in cue.tracks {
            track.player.rewind()
            let part = cue.name
            let id = track.duck.rawValue
            track.player.start(sharedClock: cue.tracks.count > 1,
                               onDone: {
                                   log("playlist   \(part) \(id) finished")
                                   guard playlistState.finish(generation: generation) else {
                                       return
                                   }
                                   let finishedIndex = playlistState.currentIndex()
                                   guard finishedIndex < cues.count - 1 else {
                                       log("playlist   complete")
                                       return
                                   }
                                   let nextIndex = playlistState.advance(delta: 1,
                                                                         maxIndex: cues.count - 1)
                                   log("playlist   auto-armed \(cueLine().trimmingCharacters(in: .whitespacesAndNewlines))")
                                   triggerCue(cues[nextIndex])
                               })
        }
    }

    @Sendable func stateJSON() -> String {
        let snapshot = playlistState.snapshot()
        let cue = cues[snapshot.index]
        let elapsedSec = snapshot.startedAt.map { min(Date().timeIntervalSince($0),
                                                      cue.durationSec) } ?? 0.0
        return """
        {"cue":{"index":\(snapshot.index),"count":\(cues.count),"name":"\(cue.name)","durationSec":\(String(format: "%.3f", cue.durationSec)),"generation":\(snapshot.generation),"elapsedSec":\(String(format: "%.3f", elapsedSec))},"playing":\(snapshot.playing ? "true" : "false"),"status":"\(jsonEscape(server.statusReport()))","health":"\(jsonEscape(server.healthReport()))"}

        """
    }

    server.onControl = { cmd in
        switch cmd {
        case "play":
            stopAllPlaylistTracks()
            let cueIndex = playlistState.currentIndex()
            let cue = cues[cueIndex]
            triggerCue(cue)
            return "playing \(cue.name)\n"
        case "stop":
            stopAllPlaylistTracks()
            log("playlist   ⏹ stopped")
            return "stopped\n"
        case "next":
            stopAllPlaylistTracks()
            _ = playlistState.advance(delta: 1, maxIndex: cues.count - 1)
            log("playlist   armed \(cueLine().trimmingCharacters(in: .whitespacesAndNewlines))")
            return cueLine()
        case "prev":
            stopAllPlaylistTracks()
            _ = playlistState.advance(delta: -1, maxIndex: cues.count - 1)
            log("playlist   armed \(cueLine().trimmingCharacters(in: .whitespacesAndNewlines))")
            return cueLine()
        case "cue":
            return cueLine()
        case "state":
            return stateJSON()
        default:
            return "unknown control: \(cmd)\n"
        }
    }

    log("playlist   ARMED — \(cues.count) cue(s) loaded. \(cueLine().trimmingCharacters(in: .whitespacesAndNewlines))")
    log("playlist   trigger: curl http://localhost:\(args.port)/play")
    log("playlist   next:    curl http://localhost:\(args.port)/next")
    log("playlist   prev:    curl http://localhost:\(args.port)/prev")
    log("playlist   cue:     curl http://localhost:\(args.port)/cue")
} else if !args.plays.isEmpty {
    if args.sine || args.mode1 {
        fputs("error: --play is mutually exclusive with --sine / --mode1\n", stderr)
        exit(2)
    }
    // Load every track first (fail fast on a bad file before connecting).
    var loaded: [(player: FilePlayer, duck: DuckID)] = []
    for play in args.plays {
        let player = FilePlayer(server: server, duck: play.duck, loop: args.loop)
        do {
            let dur = try player.load(path: play.path)
            log(String(format: "play        %@ → %@ (%.1fs, 16k/mono, %@)",
                       (play.path as NSString).lastPathComponent, play.duck.rawValue,
                       dur, args.loop ? "looping" : "once"))
            loaded.append((player, play.duck))
        } catch {
            fputs("fatal: --play \(play.path) failed: \(error.localizedDescription)\n",
                  stderr)
            exit(1)
        }
    }
    filePlayers = loaded.map { $0.player }
    let targets = loaded.map { $0.duck }
    let multi = loaded.count > 1

    // Start (or restart) all loaded tracks together. Ducks are expected to be
    // already connected (that's the point of the control channel — no restart
    // churn). Rewinds first so every trigger replays from the top.
    let triggerPlay: @Sendable () -> Void = {
        let names = targets.map { label($0) }.joined(separator: ", ")
        let present = targets.filter { server.connection(for: $0) != nil }.count
        log("play        ▶ \(names)  (\(present)/\(targets.count) ducks connected)")
        for entry in loaded {
            entry.player.rewind()
            let id = entry.duck.rawValue
            entry.player.start(sharedClock: multi,
                               onDone: { log("play        \(id) finished") })
        }
    }
    let triggerStop: @Sendable () -> Void = {
        for entry in loaded { entry.player.stop() }
        log("play        ⏹ stopped")
    }
    server.onControl = { cmd in
        switch cmd {
        case "play":
            triggerPlay()
            return "playing\n"
        case "stop":
            triggerStop()
            return "stopped\n"
        default:
            return "unknown control: \(cmd)\n"
        }
    }

    if args.waitTrigger {
        log("play        ARMED — \(loaded.count) track(s) loaded, waiting for trigger.")
        log("play        trigger:  curl http://localhost:\(args.port)/play")
        log("play        stop:     curl http://localhost:\(args.port)/stop")
        log("play        status:   curl http://localhost:\(args.port)/status")
    } else if !multi {
        // Single track, auto-start: hold-cursor mode (resumes on reconnect).
        let only = loaded[0]; let id = only.duck.rawValue
        only.player.start(sharedClock: false, onDone: { log("play        \(id) finished") })
    } else {
        // Multi-track auto-start: wait until all ducks stably connected, then fire.
        DispatchQueue.global().async {
            let deadline = Date().addingTimeInterval(30)
            func allConnected() -> Bool { targets.allSatisfy { server.connection(for: $0) != nil } }
            while Date() < deadline {
                if allConnected() { usleep(1_500_000); if allConnected() { break } }
                usleep(200_000)
            }
            triggerPlay()
        }
    }
}

// Graceful shutdown on SIGINT / SIGTERM.
let sigSrcInt  = DispatchSource.makeSignalSource(signal: SIGINT,  queue: .main)
let sigSrcTerm = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
signal(SIGINT,  SIG_IGN)
signal(SIGTERM, SIG_IGN)
let shutdown = {
    log("shutting down")
    sineGen?.stop()
    dawInput?.stop()
    filePlayers.forEach { $0.stop() }
    server.stop()
    exit(0)
}
sigSrcInt.setEventHandler  { shutdown() }
sigSrcTerm.setEventHandler { shutdown() }
sigSrcInt.resume()
sigSrcTerm.resume()

dispatchMain()
