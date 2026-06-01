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

if !args.plays.isEmpty {
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

    if loaded.count == 1 {
        // Single track: hold-cursor mode, start immediately (resumes on
        // reconnect from where it left off — no other track to stay aligned to).
        let only = loaded[0]
        let id = only.duck.rawValue
        only.player.start(sharedClock: false, onDone: { log("play        \(id) finished") })
    } else {
        // Multi-track: synchronize. Wait until ALL target ducks are connected,
        // then start every track at once on a shared wall-clock so the
        // call/response timing across ducks holds. Falls back to starting
        // anyway after a timeout if some duck never shows.
        let targets = loaded.map { $0.duck }
        let players = loaded
        DispatchQueue.global().async {
            let deadline = Date().addingTimeInterval(30)
            var sawAll = false
            while Date() < deadline {
                if targets.allSatisfy({ server.connection(for: $0) != nil }) {
                    sawAll = true; break
                }
                usleep(100_000)  // 100ms
            }
            let names = targets.map { label($0) }.joined(separator: ", ")
            if sawAll {
                log("play        all ducks connected — synchronized start: \(names)")
            } else {
                log("play        timeout waiting for all ducks; starting anyway: \(names)")
            }
            for entry in players {
                let id = entry.duck.rawValue
                entry.player.start(sharedClock: true,
                                   onDone: { log("play        \(id) finished") })
            }
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
