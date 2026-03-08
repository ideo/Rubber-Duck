// Audio Device Discovery — CoreAudio device enumeration and Teensy detection.
//
// Static utility for finding audio devices by name. Provides safe
// CoreAudio property reading that avoids CFString memory warnings.

import Foundation
import CoreAudio
import AVFoundation

enum AudioDeviceDiscovery {

    /// Teensy device info found via CoreAudio.
    struct TeensyDevice {
        let deviceID: AudioDeviceID
        let name: String       // CoreAudio device name (e.g. "Teensy MIDI_Audio")
        let uid: String?       // CoreAudio device UID
    }

    /// Search CoreAudio devices for one containing "Teensy" in its name.
    static func findTeensy() -> TeensyDevice? {
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
            if name.lowercased().contains(DuckConfig.teensyAudioDeviceName) {
                let uid = stringProperty(deviceID, selector: kAudioDevicePropertyDeviceUID)
                return TeensyDevice(deviceID: deviceID, name: name, uid: uid)
            }
        }
        return nil
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

    /// Select the best microphone — prefers Teensy, falls back to default.
    static func selectMicrophone() -> (name: String, isTeensy: Bool)? {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        ).devices

        if let teensy = devices.first(where: { $0.localizedName.lowercased().contains(DuckConfig.teensyAudioDeviceName) }) {
            return (teensy.localizedName, true)
        }

        if let defaultMic = AVCaptureDevice.default(for: .audio) {
            return (defaultMic.localizedName, false)
        }

        return nil
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
