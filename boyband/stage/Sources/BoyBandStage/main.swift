// Boy Band — Stage entry point.
//
// Week 1 deliverable. Headless CLI that:
//   1. Listens on ws://0.0.0.0:<port>/duck/{D1..D4}
//   2. Logs connect / disconnect / inbound text frames
//   3. Optionally streams a steady sine tone to every connected duck
//      (different pitch per duck so the channel routing is audible)
//
// Usage:
//   swift run BoyBandStage                 # server only, idle
//   swift run BoyBandStage --sine          # stream sine to all connected ducks
//   swift run BoyBandStage --sine D2       # solo D2 with sine, others silent
//   swift run BoyBandStage --port 3334     # explicit port (default 3334)
//
// Point a duck's NVS relay_url at ws://<this-mac>.local:3334 to wire it in.

import Foundation
import Dispatch

// MARK: - Args

struct Args {
    var port: UInt16 = 3334
    var sine: Bool = false
    var soloDuck: DuckID? = nil
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
        case "-h", "--help":
            printHelp(); exit(0)
        default:
            fputs("error: unknown arg \(a)\n", stderr)
            printHelp(); exit(2)
        }
        i += 1
    }
    return args
}

func printHelp() {
    let help = """
    Boy Band — Stage server

    Usage:
      BoyBandStage [--port N] [--sine [DUCKID]]

    Options:
      --port N         Listen port (default 3334)
      --sine           Stream a steady sine to every connected duck
      --sine DUCKID    Solo one duck (D1..D4); others stay silent
      -h, --help       Show this help

    Logs go to stdout. Each duck connects to ws://host:port/duck/{D1..D4}.
    """
    print(help)
}

// MARK: - Logging

func log(_ s: String) {
    let ts = ISO8601DateFormatter().string(from: Date())
    print("[\(ts)] \(s)")
}

// MARK: - Main

let args = parseArgs()

var sineGen: SineGenerator?  // set after server starts

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

let server = StageServer(port: args.port, callbacks: callbacks)

do {
    try server.start()
} catch {
    fputs("fatal: cannot bind port \(args.port): \(error)\n", stderr)
    exit(1)
}

log("listening on ws://0.0.0.0:\(args.port)/duck/{D1..D4}")

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

// Graceful shutdown on SIGINT / SIGTERM.
let sigSrcInt  = DispatchSource.makeSignalSource(signal: SIGINT,  queue: .main)
let sigSrcTerm = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
signal(SIGINT,  SIG_IGN)
signal(SIGTERM, SIG_IGN)
let shutdown = {
    log("shutting down")
    sineGen?.stop()
    server.stop()
    exit(0)
}
sigSrcInt.setEventHandler  { shutdown() }
sigSrcTerm.setEventHandler { shutdown() }
sigSrcInt.resume()
sigSrcTerm.resume()

dispatchMain()
