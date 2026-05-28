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
                   [--list-inputs]

    Options:
      --port N             Listen port (default 3334)
      --sine               Stream a steady sine to every connected duck
      --sine DUCKID        Solo one duck (D1..D4); others stay silent
      --duck-map FILE      Path to MAC→slot JSON map (used by /ws/duck)
      --no-duck-map        Disable /ws/duck; only test path /duck/{ID} works
      --mode1              Mode 1: read 4ch input from CoreAudio, route to ducks
      --input-device STR   Substring of input device name (default "BlackHole")
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

let callbacks = StageCallbacks(
    onConnect: { conn in
        log("connect    \(conn.duck.rawValue)  id=\(conn.id.uuidString.prefix(8))")
    },
    onDisconnect: { conn in
        log("disconnect \(conn.duck.rawValue)  id=\(conn.id.uuidString.prefix(8))")
    },
    onText: { conn, text in
        log("text       \(conn.duck.rawValue)  \(text)")
    },
    onBinary: { _, _ in
        // Duck mic frames are dropped — we use the Mac mic in Mode 2.
    }
)

// Resolve duck-map.
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
    for e in entries { log("  \(e.duck.rawValue) ← \(e.mac)") }
    return map
}()

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

// Graceful shutdown on SIGINT / SIGTERM.
let sigSrcInt  = DispatchSource.makeSignalSource(signal: SIGINT,  queue: .main)
let sigSrcTerm = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
signal(SIGINT,  SIG_IGN)
signal(SIGTERM, SIG_IGN)
let shutdown = {
    log("shutting down")
    sineGen?.stop()
    dawInput?.stop()
    server.stop()
    exit(0)
}
sigSrcInt.setEventHandler  { shutdown() }
sigSrcTerm.setEventHandler { shutdown() }
sigSrcInt.resume()
sigSrcTerm.resume()

dispatchMain()
