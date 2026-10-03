import AudioToolbox
import CoreAudio

/// Reports volume / mute of the default output device via CoreAudio (event-driven, no polling).
@MainActor
final class VolumeMonitor {
    private let hud: HUDModel
    private var deviceID = AudioObjectID(kAudioObjectUnknown)
    private var deviceListener: AudioObjectPropertyListenerBlock?
    private var lastVolume: Float?
    private var lastMuted: Bool?

    private static let system = AudioObjectID(kAudioObjectSystemObject)

    private static func address(_ selector: AudioObjectPropertySelector,
                                scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static var volumeAddress: AudioObjectPropertyAddress {
        address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioDevicePropertyScopeOutput)
    }
    private static var muteAddress: AudioObjectPropertyAddress {
        address(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput)
    }

    init(hud: HUDModel) {
        self.hud = hud
        attachToDefaultDevice()

        // Speaker/headphones changed -> listen on the new device
        var address = Self.address(kAudioHardwarePropertyDefaultOutputDevice)
        AudioObjectAddPropertyListenerBlock(Self.system, &address, .main) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.attachToDefaultDevice() }
        }
    }

    private func attachToDefaultDevice() {
        detach()

        var address = Self.address(kAudioHardwarePropertyDefaultOutputDevice)
        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(Self.system, &address, 0, nil, &size, &id) == noErr,
              id != kAudioObjectUnknown else { return }
        deviceID = id

        // Record current values so switching devices is not mistaken for a volume change
        lastVolume = readVolume()
        lastMuted = readMuted()

        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.deviceDidChange() }
        }
        deviceListener = listener
        var volume = Self.volumeAddress
        var mute = Self.muteAddress
        AudioObjectAddPropertyListenerBlock(id, &volume, .main, listener)
        AudioObjectAddPropertyListenerBlock(id, &mute, .main, listener)
    }

    private func detach() {
        guard deviceID != kAudioObjectUnknown, let listener = deviceListener else { return }
        var volume = Self.volumeAddress
        var mute = Self.muteAddress
        AudioObjectRemovePropertyListenerBlock(deviceID, &volume, .main, listener)
        AudioObjectRemovePropertyListenerBlock(deviceID, &mute, .main, listener)
        deviceListener = nil
    }

    /// Changes volume by `delta` (0...1). Returns false if the device does not allow it (e.g. HDMI) -> let macOS handle it.
    func adjust(by delta: Float) -> Bool {
        guard let current = readVolume() else { return false }
        var address = Self.volumeAddress
        var value = min(max(current + delta, 0), 1)
        guard AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &value) == noErr
        else { return false }
        // Raising the volume while muted unmutes, like macOS
        if delta > 0, readMuted() == true { _ = setMuted(false) }
        return true
    }

    func toggleMute() -> Bool {
        guard let muted = readMuted() else { return false }
        return setMuted(!muted)
    }

    private func setMuted(_ muted: Bool) -> Bool {
        var address = Self.muteAddress
        var value: UInt32 = muted ? 1 : 0
        return AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value) == noErr
    }

    private func deviceDidChange() {
        let volume = readVolume()
        let muted = readMuted()
        defer { lastVolume = volume; lastMuted = muted }
        guard volume != lastVolume || muted != lastMuted else { return }
        hud.show(.volume(muted: muted ?? false), value: Double(volume ?? 0))
    }

    private func readVolume() -> Float? {
        var address = Self.volumeAddress
        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectHasProperty(deviceID, &address),
              AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    private func readMuted() -> Bool? {
        var address = Self.muteAddress
        var value = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectHasProperty(deviceID, &address),
              AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value != 0
    }
}
