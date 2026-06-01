// FilePlayer — stream an audio file to one duck as paced 16k/mono/int16 PCM.
//
// The duck plays raw: its I2S is hard-locked to 16000 Hz mono int16 (see
// bambu/firmware/main/config.h). It does NOT resample. So ALL rate/format
// conversion happens here on the Mac, once, offline, before we send.
//
// Why this is the safest audio source for the duck (least likely to glitch):
//   1. Resample-once: decode → AVAudioConverter → 16k/mono/int16, fully in
//      memory, before any sending. No live device clock, no realtime
//      resampler drift.
//   2. Real-time pacing: 320 samples (640 bytes = 20 ms) every 20 ms. Keeps
//      the duck's 1 MB speaker buffer near-empty so it can NEVER overflow.
//      Overflow is exactly what triggers the firmware's drop path; an odd-
//      byte drop there shifts every subsequent int16 → white noise (the bug
//      fixed by the aligned-drop guard in agent.c on_binary). We avoid the
//      whole situation by not over-filling.
//   3. Even byte counts always: 320-sample chunks are inherently 2-byte
//      aligned, so the duck never receives a half-sample.
//
// Usage (from main.swift): --play <file> <DUCKID> [--loop]
// Supports anything AVAudioFile can open: wav, aiff, mp3, m4a, caf...

import Foundation
import AVFoundation
import Dispatch

private let kSampleRate: Double = 16000
private let kSamplesPerChunk = 320            // 20 ms @ 16 kHz
private let kChunkBytes = kSamplesPerChunk * 2 // int16 → 2 bytes

final class FilePlayer: @unchecked Sendable {
    private let server: StageServer
    private let duck: DuckID
    private let loop: Bool
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "boyband.stage.fileplayer")

    /// The fully-decoded, resampled audio as raw int16 LE bytes.
    private var pcm: [UInt8] = []
    /// Read cursor into `pcm`, in bytes. Always a multiple of 2.
    private var cursor: Int = 0

    init(server: StageServer, duck: DuckID, loop: Bool) {
        self.server = server
        self.duck = duck
        self.loop = loop
    }

    /// Decode + resample the file into 16k/mono/int16. Throws on failure.
    /// Returns the duration in seconds for logging.
    func load(path: String) throws -> Double {
        let url = URL(fileURLWithPath: path)
        let file = try AVAudioFile(forReading: url)
        let inFormat = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0 else {
            throw err("file has zero frames: \(path)")
        }

        // Read the whole file into a buffer at its native format.
        guard let inBuf = AVAudioPCMBuffer(pcmFormat: inFormat,
                                           frameCapacity: frameCount) else {
            throw err("could not allocate input buffer")
        }
        try file.read(into: inBuf)

        // Target: 16 kHz, mono, int16, interleaved — the duck's locked format.
        guard let outFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                            sampleRate: kSampleRate,
                                            channels: 1,
                                            interleaved: true) else {
            throw err("could not build 16k/mono/int16 output format")
        }
        guard let converter = AVAudioConverter(from: inFormat, to: outFormat) else {
            throw err("no converter from \(inFormat) to \(outFormat)")
        }

        // Output capacity: scale by the sample-rate ratio, plus slack.
        let ratio = kSampleRate / inFormat.sampleRate
        let outCap = AVAudioFrameCount(Double(frameCount) * ratio) + 4096
        guard let outBuf = AVAudioPCMBuffer(pcmFormat: outFormat,
                                            frameCapacity: outCap) else {
            throw err("could not allocate output buffer")
        }

        // One-shot convert: hand over the whole input buffer once, then EOS.
        var fed = false
        var convErr: NSError?
        let status = converter.convert(to: outBuf, error: &convErr) { _, inStatus in
            if fed {
                inStatus.pointee = .endOfStream
                return nil
            }
            fed = true
            inStatus.pointee = .haveData
            return inBuf
        }
        if status == .error || convErr != nil {
            throw err("conversion failed: \(convErr?.localizedDescription ?? "unknown")")
        }

        // Extract interleaved int16 → raw LE bytes.
        let outFrames = Int(outBuf.frameLength)
        guard let ch = outBuf.int16ChannelData?[0] else {
            throw err("no int16 channel data after conversion")
        }
        var bytes = [UInt8]()
        bytes.reserveCapacity(outFrames * 2)
        for i in 0..<outFrames {
            let s = ch[i]
            bytes.append(UInt8(truncatingIfNeeded: s))
            bytes.append(UInt8(truncatingIfNeeded: Int(s) >> 8))
        }
        self.pcm = bytes
        return Double(outFrames) / kSampleRate
    }

    /// Start paced playback. `onDone` fires when a non-looping file finishes.
    ///
    /// Two clock modes:
    /// - `sharedClock == false` (default, single-duck): HOLD the cursor while
    ///   the duck is disconnected, so playback resumes from where it left off
    ///   on reconnect. Good when there's only one track — no alignment to keep.
    /// - `sharedClock == true` (multi-track / call-response): ALWAYS advance
    ///   the cursor on wall-clock, sending only when connected. Multiple tracks
    ///   started together stay time-aligned (so the back-and-forth timing
    ///   holds). A momentarily-disconnected duck loses frames rather than
    ///   drifting out of sync with the others.
    /// Reset to the top so the next start() replays from the beginning.
    func rewind() { cursor = 0 }

    /// Simple real-time trickle: one 20ms chunk (640 B) per 20ms tick =
    /// 32 KB/s = the duck's drain rate. This is the version that played both
    /// ducks cleanly for several turns. Backpressure/jitter is handled DOWN-
    /// stream in DuckConnection.sendPCM, which drops chunks (per-duck, isolated)
    /// when a duck's socket backs up — so a network jam on one duck becomes a
    /// brief skip on that duck, NOT progressive garble and NOT a stall on the
    /// other duck. (Earlier attempts to fix garble by changing the PACING here
    /// — prebuffer burst, wall-clock lead — were wrong-headed; the real issue
    /// was the shared send queue + no frame-dropping. See STATE.md.)
    func start(sharedClock: Bool = false, onDone: (@Sendable () -> Void)? = nil) {
        timer?.cancel()  // re-entrant: drop any prior timer
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: .milliseconds(20))
        t.setEventHandler { [weak self] in
            guard let self else { return }
            let conn = self.server.connection(for: self.duck)
            if !sharedClock && conn == nil {
                return  // hold-mode (single duck): wait for reconnect
            }
            let end = min(self.cursor + kChunkBytes, self.pcm.count)
            if self.cursor < end {
                if let conn { conn.sendPCM(Data(self.pcm[self.cursor..<end])) }
                self.cursor = end  // shared-clock advances even if conn == nil
            }
            if self.cursor >= self.pcm.count {
                if self.loop { self.cursor = 0 }
                else { self.stop(); onDone?() }
            }
        }
        timer = t
        t.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func err(_ msg: String) -> NSError {
        NSError(domain: "FilePlayer", code: 1,
                userInfo: [NSLocalizedDescriptionKey: msg])
    }
}
