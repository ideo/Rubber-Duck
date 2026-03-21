// Audio Device Discovery — CoreAudio device enumeration and Teensy detection.
//
// Static utility for finding audio devices by name. Provides safe
// CoreAudio property reading that avoids CFString memory warnings.

import Foundation
import CoreAudio
import AVFoundation

/// Weak-reference wrapper passed as CoreAudio callback context.
/// Prevents use-after-free: even if the listener is deallocated while
/// CoreAudio fires the callback on its thread, this context is still
/// a valid heap object and the weak reference safely becomes nil.
private class DeviceChangeContext {
    weak var listener: AudioDeviceDiscovery.DeviceChangeListener?
    init(_ listener: AudioDeviceDiscovery.DeviceChangeListener) { self.listener = listener }
}

/// CoreAudio property listener callback — must be a plain C function (not a closure).
/// Bounces to main thread and calls the DeviceChangeListener's onChange handler.
private func deviceChangeCallback(
    _ objectID: AudioObjectID,
    _ numberAddresses: UInt32,
    _ addresses: UnsafePointer<AudioObjectPropertyAddress>,
    _ clientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let ptr = clientData else { return noErr }
    let context = Unmanaged<DeviceChangeContext>.fromOpaque(ptr).takeUnretainedValue()
    guard let listener = context.listener else { return noErr }
    DispatchQueue.main.async { listener.onChange?() }
    return noErr
}

enum AudioDeviceDiscovery {

    /// A duck-compatible UAC audio device found via CoreAudio.
    struct DuckAudioDevice {
        let deviceID: AudioDeviceID
        let name: String       // CoreAudio device name (e.g. "Teensy MIDI_Audio", "Duck Duck Duck")
        let uid: String?       // CoreAudio device UID
        let isTeensy: Bool     // true = Teensy, false = ESP32-S3 or other duck UAC
    }

    /// Search CoreAudio devices for one matching any known duck UAC device name.
    /// Checks Teensy ("Teensy MIDI_Audio") and ESP32-S3 ("Duck Duck Duck").
    static func findDuckDevice() -> DuckAudioDevice? {
        var propSize: UInt32 = 0
        var propAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propAddress, 0, nil, &propSize)
        let deviceCount = Int(propSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propAddress, 0, nil, &propSize, &deviceIDs)

        for deviceID in deviceIDs {
            guard let name = stringProperty(deviceID, selector: kAudioObjectPropertyName) else {
                continue
            }
            let lower = name.lowercased()
            for pattern in DuckConfig.duckAudioDeviceNames {
                if lower.contains(pattern) {
                    let uid = stringProperty(deviceID, selector: kAudioDevicePropertyDeviceUID)
                    let isTeensy = lower.contains(DuckConfig.teensyAudioDeviceName)
                    return DuckAudioDevice(deviceID: deviceID, name: name, uid: uid, isTeensy: isTeensy)
                }
            }
        }
        return nil
    }

    /// Legacy convenience — search for Teensy specifically.
    static func findTeensy() -> DuckAudioDevice? {
        guard let device = findDuckDevice(), device.isTeensy else { return nil }
        return device
    }

    /// List all available microphones via AVCaptureDevice.
    static func listMicrophones() -> [(index: Int, name: String)] {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        ).devices
        return devices.enumerated().map { ($0.offset, $0.element.localizedName) }
    }

    /// Select the best microphone — prefers duck UAC device, falls back to default.
    static func selectMicrophone() -> (name: String, isDuckDevice: Bool)? {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        ).devices

        // Check for any duck UAC device (Teensy or ESP32-S3)
        for device in devices {
            let lower = device.localizedName.lowercased()
            for pattern in DuckConfig.duckAudioDeviceNames {
                if lower.contains(pattern) {
                    return (device.localizedName, true)
                }
            }
        }

        if let defaultMic = AVCaptureDevice.default(for: .audio) {
            return (defaultMic.localizedName, false)
        }

        return nil
    }

    // MARK: - Device Change Listener

    /// Watches for USB audio device plug/unplug via CoreAudio property listener.
    /// Fires callback on any device list change (add, remove, config change).
    class DeviceChangeListener {
        private var listening = false
        var onChange: (() -> Void)?

        /// Retained context passed to CoreAudio — prevents use-after-free.
        /// The context holds a weak ref back to us, so the callback safely
        /// no-ops if we've been deallocated.
        private var context: DeviceChangeContext?

        func start() {
            guard !listening else { return }
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDevices,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            // Create a context that CoreAudio holds a pointer to.
            // passRetained keeps it alive; we balance in stop().
            let ctx = DeviceChangeContext(self)
            self.context = ctx
            let ctxPtr = Unmanaged.passRetained(ctx).toOpaque()
            let status = AudioObjectAddPropertyListener(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                deviceChangeCallback,
                ctxPtr
            )
            listening = (status == noErr)
            if !listening {
                // Balance the retain if registration failed
                Unmanaged.passUnretained(ctx).release()
                self.context = nil
            }
        }

        func stop() {
            guard listening, let ctx = context else { return }
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDevices,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            let ctxPtr = Unmanaged.passUnretained(ctx).toOpaque()
            AudioObjectRemovePropertyListener(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                deviceChangeCallback,
                ctxPtr
            )
            // Balance the passRetained from start()
            Unmanaged.passUnretained(ctx).release()
            // Nil the weak ref so any in-flight callbacks no-op
            ctx.listener = nil
            self.context = nil
            listening = false
        }

        deinit { stop() }
    }

    // MARK: - CoreAudio Volume

    /// Set the output volume on a specific CoreAudio device (0.0–1.0).
    /// Uses the virtual main volume property which controls all channels.
    static func setDeviceVolume(_ deviceID: AudioDeviceID, volume: Float) {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        // Check if volume property is settable
        var settable: DarwinBoolean = false
        let canSet = AudioObjectIsPropertySettable(deviceID, &address, &settable)
        guard canSet == noErr, settable.boolValue else {
            // Fall back to per-channel volume
            address.mSelector = kAudioDevicePropertyVolumeScalar
            address.mElement = 1  // Channel 1 (left/mono)
            let canSetCh = AudioObjectIsPropertySettable(deviceID, &address, &settable)
            guard canSetCh == noErr, settable.boolValue else { return }

            var vol = max(0, min(1, volume))
            AudioObjectSetPropertyData(deviceID, &address, 0, nil,
                                       UInt32(MemoryLayout<Float32>.size), &vol)
            address.mElement = 2  // Channel 2 (right) — may not exist on mono
            AudioObjectSetPropertyData(deviceID, &address, 0, nil,
                                       UInt32(MemoryLayout<Float32>.size), &vol)
            return
        }

        var vol = max(0, min(1, volume))
        AudioObjectSetPropertyData(deviceID, &address, 0, nil,
                                   UInt32(MemoryLayout<Float32>.size), &vol)
    }

    // MARK: - CoreAudio Helpers

    /// Safe CoreAudio string property reader — avoids UnsafeMutableRawPointer
    /// warnings from passing CFString directly to AudioObjectGetPropertyData.
    static func stringProperty(_ deviceID: AudioDeviceID, selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr, size > 0 else {
            return nil
        }
        let buf = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<CFString>.alignment)
        defer { buf.deallocate() }
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, buf) == noErr else {
            return nil
        }
        return buf.load(as: CFString.self) as String
    }
}
