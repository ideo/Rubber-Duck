// DAWInput — multichannel audio input → per-duck PCM.
//
// Week 2: Mode 1's upstream source. A DAW (Logic / Reaper / Ableton) bounces
// 4 tracks out to BlackHole (a free virtual audio device); Stage reads those
// 4 channels and ships each to the matching duck.
//
// Why BlackHole: it presents itself as a normal CoreAudio input device, so
// we can use the same AVAudioEngine input pattern that would work for a
// real multichannel audio interface. We don't actually require BlackHole —
// any multichannel input device with ≥4 channels works. The default name
// match is "BlackHole" because that's what we'll use in practice.
//
// Pipeline:
//   1. Pick an input device by name substring (or first 4-channel device)
//   2. AVAudioEngine.inputNode at that device's native format
//   3. Tap → AVAudioConverter → int16 @ 16 kHz, channel count preserved
//   4. For each frame, demux: ch0→D1, ch1→D2, ch2→D3, ch3→D4
//   5. sendPCM() to each duck's connection
//
// Pacing: AVAudioEngine drives the tap on real-time audio clock. We just
// forward each callback's worth of samples; the firmware buffer handles
// small jitter. No explicit DispatchSourceTimer needed here (unlike
// SineGenerator) because the audio device IS the clock.

import Foundation
import AVFoundation
import CoreAudio

/// Slot assignment for input channels. Default is positional: ch N → D(N+1).
struct DAWChannelMap: Sendable {
    /// channelMap[N] = which duck gets channel N. nil = drop that channel.
    let channelMap: [DuckID?]

    /// Default 4-channel positional mapping.
    static let defaultFourChannel = DAWChannelMap(
        channelMap: [.D1, .D2, .D3, .D4]
    )
}

final class DAWInput: @unchecked Sendable {
    private let server: StageServer
    private let map: DAWChannelMap
    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    /// Format we send to ducks: int16, 16 kHz, channels = map.count.
    private let outputFormat: AVAudioFormat
    /// Per-channel rolling byte buffer to make ~20 ms send chunks.
    private var perChannelBuf: [[UInt8]]
    /// 20 ms @ 16 kHz int16 = 320 samples = 640 bytes.
    private let chunkBytes = 640

    init(server: StageServer, map: DAWChannelMap = .defaultFourChannel) {
        self.server = server
        self.map = map
        self.outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: AVAudioChannelCount(map.channelMap.count),
            interleaved: true
        )!
        self.perChannelBuf = Array(repeating: [], count: map.channelMap.count)
    }

    /// List all input-capable audio devices, name + channel count. Diagnostic.
    static func listInputDevices() -> [(name: String, channels: Int, id: AudioDeviceID)] {
        var size: UInt32 = 0
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject),
                                       &addr, 0, nil, &size)
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                   &addr, 0, nil, &size, &ids)

        var results: [(String, Int, AudioDeviceID)] = []
        for id in ids {
            let name = deviceName(id) ?? "<unknown>"
            let inCh = inputChannelCount(id)
            if inCh > 0 {
                results.append((name, inCh, id))
            }
        }
        return results
    }

    /// Find a device whose name contains `match` (case-insensitive). If
    /// nil, picks the first input device with ≥ requested channels.
    static func findDevice(matching match: String?, minChannels: Int) -> AudioDeviceID? {
        let devices = listInputDevices()
        if let match = match?.lowercased() {
            return devices.first { $0.name.lowercased().contains(match) }?.id
        }
        return devices.first { $0.channels >= minChannels }?.id
    }

    // MARK: - Start / stop

    func start(deviceID: AudioDeviceID) throws {
        // TODO(boy-band/week-2): Explicit input-device selection on macOS 26.
        //
        // The AVAudioEngine-level API for "use THIS device, not the system
        // default" is not exposed to Swift in macOS 26 (AUAudioUnit's
        // `audioUnit` property is unavailable from Swift). The proper fix
        // is to rewrite this class around an AUHAL output unit configured
        // for input — AudioComponentInstanceNew with kAudioUnitSubType_HALOutput,
        // then kAudioOutputUnitProperty_CurrentDevice → deviceID. ~80 lines
        // of CoreAudio C-style code in place of AVAudioEngine; same downstream
        // tap / converter / demux pipeline.
        //
        // For now: log which device was selected, but actually capture from
        // whatever the system default input is. Workaround at the venue:
        // set BlackHole 4ch as the system default input in System Settings
        // → Sound → Input before starting Stage.
        if let name = deviceName(deviceID) {
            log_stderr("DAWInput: explicit selection of '\(name)' " +
                       "not yet implemented; using system default input. " +
                       "Set the device as system default in System Settings.")
        }
        _ = deviceID  // silence unused warning until rewrite

        // Read the system default input device's native format.
        let inputFormat = engine.inputNode.inputFormat(forBus: 0)
        guard inputFormat.channelCount >= AVAudioChannelCount(map.channelMap.count) else {
            throw NSError(domain: "DAWInput", code: 1, userInfo: [
                NSLocalizedDescriptionKey:
                    "Input device only has \(inputFormat.channelCount) channels; " +
                    "need at least \(map.channelMap.count)."
            ])
        }

        // Native → 16-bit @ 16 kHz, interleaved, channels preserved.
        guard let conv = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw NSError(domain: "DAWInput", code: 2, userInfo: [
                NSLocalizedDescriptionKey:
                    "Could not build AVAudioConverter from \(inputFormat) → \(outputFormat)"
            ])
        }
        converter = conv

        // Tap at native format. Bufsize 4800 samples = 100 ms @ 48 kHz —
        // small enough for latency, large enough to amortize callback cost.
        engine.inputNode.installTap(onBus: 0,
                                    bufferSize: 4800,
                                    format: inputFormat) { [weak self] buf, _ in
            self?.handle(input: buf)
        }

        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        converter = nil
        perChannelBuf = Array(repeating: [], count: map.channelMap.count)
    }

    // MARK: - Audio processing

    private func handle(input: AVAudioPCMBuffer) {
        guard let conv = converter else { return }

        // Compute output capacity. Ratio of sample rates determines output frames.
        let ratio = outputFormat.sampleRate / input.format.sampleRate
        let outCap = AVAudioFrameCount(Double(input.frameLength) * ratio + 64)
        guard let out = AVAudioPCMBuffer(pcmFormat: outputFormat,
                                         frameCapacity: outCap) else { return }

        var error: NSError?
        var fed = false
        let status = conv.convert(to: out, error: &error) { _, statusPtr in
            // AVAudioConverter pulls; provide the input buffer once.
            if fed {
                statusPtr.pointee = .noDataNow
                return nil
            }
            fed = true
            statusPtr.pointee = .haveData
            return input
        }

        if status == .error || error != nil {
            // Don't spam; one error usually means the rest will follow.
            // Resetting the converter would be heavier than just dropping.
            return
        }

        guard let int16Ptr = out.int16ChannelData?[0] else { return }
        let frames = Int(out.frameLength)
        let chans = Int(outputFormat.channelCount)
        // int16Ptr is interleaved: [c0,c1,c2,c3, c0,c1,c2,c3, ...].
        for c in 0..<chans {
            guard let duck = map.channelMap[c] else { continue }
            // Extract this channel into perChannelBuf[c] as raw bytes.
            for f in 0..<frames {
                let s = int16Ptr[f * chans + c]
                perChannelBuf[c].append(UInt8(truncatingIfNeeded: s))
                perChannelBuf[c].append(UInt8(truncatingIfNeeded: Int(s) >> 8))
            }
            // Flush full 20 ms chunks to the duck.
            while perChannelBuf[c].count >= chunkBytes {
                let chunk = Data(perChannelBuf[c].prefix(chunkBytes))
                perChannelBuf[c].removeFirst(chunkBytes)
                if let conn = server.connection(for: duck) {
                    conn.sendPCM(chunk)
                }
            }
        }
    }

}

private func log_stderr(_ s: String) {
    fputs("[stage-dawinput] " + s + "\n", stderr)
}

// MARK: - Device name / channel introspection (file-private helpers)

private func deviceName(_ id: AudioDeviceID) -> String? {
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioObjectPropertyName,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    // CoreAudio expects to write a CFStringRef (a retained reference). We pass
    // an Unmanaged box and take ownership on success — that's the canonical
    // Swift bridge for this property.
    var unmanaged: Unmanaged<CFString>? = nil
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    let status = withUnsafeMutablePointer(to: &unmanaged) { ptr -> OSStatus in
        AudioObjectGetPropertyData(id, &addr, 0, nil, &size, ptr)
    }
    guard status == noErr, let cf = unmanaged?.takeRetainedValue() else { return nil }
    return cf as String
}

private func inputChannelCount(_ id: AudioDeviceID) -> Int {
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyStreamConfiguration,
        mScope: kAudioObjectPropertyScopeInput,
        mElement: kAudioObjectPropertyElementMain)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr,
          size > 0 else { return 0 }
    let buf = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: 4)
    defer { buf.deallocate() }
    guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, buf) == noErr else {
        return 0
    }
    let list = buf.assumingMemoryBound(to: AudioBufferList.self)
    // AudioBufferList has a flexible-array-member style layout: an mNumberBuffers
    // count followed by N AudioBuffers. UnsafeMutableAudioBufferListPointer wraps
    // this without ever taking the address of a temporary.
    let listPtr = UnsafeMutableAudioBufferListPointer(list)
    var total = 0
    for b in listPtr { total += Int(b.mNumberChannels) }
    return total
}
