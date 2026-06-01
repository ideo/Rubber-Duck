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
// FRAME SIZE — match the Bambu relay (the PROVEN-working reference), which
// sends FEW LARGE binary frames (whole ElevenLabs chunks, up to ~320KB). We
// were sending 640-byte (20ms) frames = ~50 WS frames/sec, ~10x the per-frame
// overhead on the duck's WS event loop → choppy delivery → underrun. 16 KB
// matches the duck's esp_websocket_client buffer_size (16384) and cuts frame
// rate to ~2/sec. Must stay even (int16 alignment); 16384 is even.
private let kChunkBytes = 16384               // 16 KB ≈ 512 ms @ 16 kHz mono

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

    /// PREBUFFER playback. Pre-recorded audio is not interactive, so the right
    /// move is to push the whole track into the duck's 1 MB speaker buffer up
    /// front and let it play out from there — then WiFi jitter/slowness can't
    /// underrun it ("slow with gaps"). We pace to wall-clock + a large LEAD so
    /// the duck buffer holds up to ~LEAD seconds ahead; for our ~23s tracks
    /// that's effectively the entire track buffered. Stays under the firmware's
    /// 1 MB (no overflow). cursor == bytes sent == file position.
    ///
    /// This failed before ONLY because DFS clocked the duck down and it choked
    /// on the burst-receive; with the CPU pinned (BOYBAND build) it's fine.
    /// 700 KB ≈ 22 s of lead, just under the 1 MB buffer.
    private let leadBytes = 700_000

    func start(sharedClock: Bool = false, onDone: (@Sendable () -> Void)? = nil) {
        timer?.cancel()  // re-entrant: drop any prior timer
        let startTime = DispatchTime.now()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: .milliseconds(10))
        t.setEventHandler { [weak self] in
            guard let self else { return }
            let conn = self.server.connection(for: self.duck)
            if !sharedClock && conn == nil { return }  // hold for single-duck reconnect
            // Send everything up to (real-time position + big lead). At t=0 this
            // immediately pushes ~700KB (most/all of the track) into the buffer.
            let elapsedS = Double(DispatchTime.now().uptimeNanoseconds
                                  - startTime.uptimeNanoseconds) / 1_000_000_000.0
            let target = Int(elapsedS * 2.0 * kSampleRate) + self.leadBytes
            while self.cursor < self.pcm.count, self.cursor < target {
                let end = min(self.cursor + kChunkBytes, self.pcm.count)
                if let conn { conn.sendPCM(Data(self.pcm[self.cursor..<end])) }
                self.cursor = end
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
