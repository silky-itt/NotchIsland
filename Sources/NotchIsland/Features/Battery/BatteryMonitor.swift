import Foundation
import IOKit.ps
import Observation

/// Watches the battery via IOKit. macOS calls back when battery/power changes -> no timer needed.
@Observable
@MainActor
final class BatteryMonitor {
    private(set) var hasBattery = false
    private(set) var level = 100
    private(set) var isCharging = false
    private(set) var isPluggedIn = false

    @ObservationIgnored private var runLoopSource: CFRunLoopSource?

    init() {
        update()
        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
            // The source is attached to the main run loop, so the callback runs on the main thread
            MainActor.assumeIsolated { monitor.update() }
        }
        if let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = source
        }
    }

    private func update() {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
            else { continue }

            let current = description[kIOPSCurrentCapacityKey] as? Int ?? 0
            let max = description[kIOPSMaxCapacityKey] as? Int ?? 100
            hasBattery = true
            level = max > 0 ? Int((Double(current) / Double(max) * 100).rounded()) : current
            isCharging = description[kIOPSIsChargingKey] as? Bool ?? false
            isPluggedIn = description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            return
        }
        hasBattery = false
    }
}
