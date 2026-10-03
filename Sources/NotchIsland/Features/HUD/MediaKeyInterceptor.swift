import AppKit
import ApplicationServices
import Observation

/// Optional: intercepts volume/brightness/mute keys to replace the macOS HUD with the notch HUD.
/// Same approach as boring.notch and mew-notch: a CGEventTap on system-defined events (needs Accessibility permission),
/// swallow the key and change the volume/brightness ourselves.
///
/// Safe by design: the key is only swallowed when the change succeeded. If it cannot be adjusted (e.g. HDMI speakers have no volume)
/// the key is passed back to macOS as usual.
@Observable
@MainActor
final class MediaKeyInterceptor {
    private(set) var isEnabled: Bool

    @ObservationIgnored private let volume: VolumeMonitor
    @ObservationIgnored private let brightness: BrightnessMonitor
    @ObservationIgnored private var tap: CFMachPort?
    @ObservationIgnored private var source: CFRunLoopSource?
    @ObservationIgnored private var swallowedKeys: Set<Int> = []
    @ObservationIgnored private var trustPolling: Task<Void, Never>?

    private static let defaultsKey = "replaceSystemHUD"
    private static let promptedKey = "didPromptAccessibility"
    private static let systemDefinedEvent = CGEventType(rawValue: 14)!
    private static let step: Float = 1.0 / 16.0

    private enum Key: Int {
        case soundUp = 0, soundDown = 1, brightnessUp = 2, brightnessDown = 3, mute = 7
    }

    init(volume: VolumeMonitor, brightness: BrightnessMonitor) {
        self.volume = volume
        self.brightness = brightness
        // Off by default: macOS keeps showing its own volume/brightness bars unless the user opts in
        isEnabled = UserDefaults.standard.object(forKey: Self.defaultsKey) as? Bool ?? false
    }

    func startIfEnabled() {
        guard isEnabled else { return }
        // Ask for permission only on the first launch, not every time it is missing
        let shouldPrompt = !AXIsProcessTrusted() && !UserDefaults.standard.bool(forKey: Self.promptedKey)
        if shouldPrompt { UserDefaults.standard.set(true, forKey: Self.promptedKey) }
        start(prompt: shouldPrompt)
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.defaultsKey)
        if enabled { start(prompt: true) } else { stop() }
    }

    // MARK: - Event tap

    private func start(prompt: Bool) {
        guard tap == nil else { return }

        guard AXIsProcessTrusted() else {
            guard prompt else { return }
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            // Wait for the user to grant permission in System Settings (up to ~2 minutes), then start automatically
            trustPolling?.cancel()
            trustPolling = Task {
                for _ in 0..<60 {
                    try? await Task.sleep(for: .seconds(2))
                    guard !Task.isCancelled, isEnabled else { return }
                    if AXIsProcessTrusted() { start(prompt: false); return }
                }
            }
            return
        }

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let interceptor = Unmanaged<MediaKeyInterceptor>.fromOpaque(userInfo).takeUnretainedValue()
            // The tap is attached to the main run loop, so the callback runs on the main thread
            return MainActor.assumeIsolated { interceptor.handle(type: type, event: event) }
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << Self.systemDefinedEvent.rawValue),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            NSLog("NotchIsland: could not create the event tap")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
    }

    private func stop() {
        trustPolling?.cancel()
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        swallowedKeys.removeAll()
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // macOS disables the tap if the callback is too slow -> re-enable it
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        guard type == Self.systemDefinedEvent,
              let nsEvent = NSEvent(cgEvent: event),
              nsEvent.subtype.rawValue == 8   // media / special keys
        else { return Unmanaged.passUnretained(event) }

        let data = nsEvent.data1
        let keyCode = (data & 0xFFFF_0000) >> 16
        let isDown = ((data & 0xFF00) >> 8) == 0xA
        guard let key = Key(rawValue: keyCode) else { return Unmanaged.passUnretained(event) }

        // Key up: swallow it if we swallowed the key down
        guard isDown else {
            return swallowedKeys.remove(key.rawValue) != nil ? nil : Unmanaged.passUnretained(event)
        }

        // Option (+Shift) is a macOS shortcut (opens Sound/Displays settings, fine steps) -> let macOS handle it
        if nsEvent.modifierFlags.contains(.option) { return Unmanaged.passUnretained(event) }

        let handled: Bool
        switch key {
        case .soundUp: handled = volume.adjust(by: Self.step)
        case .soundDown: handled = volume.adjust(by: -Self.step)
        case .mute: handled = volume.toggleMute()
        case .brightnessUp: handled = brightness.adjust(by: Self.step)
        case .brightnessDown: handled = brightness.adjust(by: -Self.step)
        }
        guard handled else { return Unmanaged.passUnretained(event) }
        swallowedKeys.insert(key.rawValue)
        return nil
    }
}
