import CoreGraphics
import Foundation

/// Reports built-in display brightness. Apple has no public API, so this uses DisplayServices (private):
/// if the system renames or removes it, only the brightness HUD is lost and the app keeps running.
@MainActor
final class BrightnessMonitor {
    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private typealias Register = @convention(c) (CGDirectDisplayID, UnsafeRawPointer?, CFNotificationCallback) -> Int32

    /// A C callback cannot capture context -> go through a static
    private static weak var current: BrightnessMonitor?
    /// The brightness keys step by 1/16 ≈ 0.0625; automatic ambient-light changes are smaller steps -> ignored
    private static let minimumStep: Float = 0.04

    private let hud: HUDModel
    private var lastShown: Float?
    private var display: CGDirectDisplayID?
    private var getBrightness: GetBrightness?
    private var setBrightness: SetBrightness?

    init(hud: HUDModel) {
        self.hud = hud
        guard let display = Self.builtInDisplay(),
              let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW),
              let getSymbol = dlsym(handle, "DisplayServicesGetBrightness"),
              let registerSymbol = dlsym(handle, "DisplayServicesRegisterForBrightnessChangeNotifications")
        else { return }

        self.display = display
        getBrightness = unsafeBitCast(getSymbol, to: GetBrightness.self)
        setBrightness = dlsym(handle, "DisplayServicesSetBrightness").map { unsafeBitCast($0, to: SetBrightness.self) }

        var initial: Float = 0
        if getBrightness?(display, &initial) == 0 { lastShown = initial }

        Self.current = self
        _ = unsafeBitCast(registerSymbol, to: Register.self)(display, nil) { _, _, _, _, info in
            let value = ((info as? [String: Any])?["value"] as? NSNumber)?.floatValue
            guard let value else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated { BrightnessMonitor.current?.brightnessDidChange(value) }
            }
        }
    }

    /// Changes brightness by `delta` (0...1). Returns false if it cannot be adjusted -> let macOS handle it.
    func adjust(by delta: Float) -> Bool {
        guard let display, let getBrightness, let setBrightness else { return false }
        var current: Float = 0
        guard getBrightness(display, &current) == 0 else { return false }
        return setBrightness(display, min(max(current + delta, 0), 1)) == 0
    }

    private func brightnessDidChange(_ value: Float) {
        if let lastShown, abs(value - lastShown) < Self.minimumStep, value > 0.001, value < 0.999 { return }
        lastShown = value
        hud.show(.brightness, value: Double(value))
    }

    private static func builtInDisplay() -> CGDirectDisplayID? {
        var ids = [CGDirectDisplayID](repeating: 0, count: 8)
        var count: UInt32 = 0
        CGGetActiveDisplayList(UInt32(ids.count), &ids, &count)
        return ids.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 }
    }
}
