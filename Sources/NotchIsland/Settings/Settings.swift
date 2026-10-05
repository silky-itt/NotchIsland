import Foundation

/// UserDefaults keys and their defaults. SwiftUI views bind with @AppStorage; other code reads through `Settings`.
enum Settings {
    enum Key {
        static let openOnHover = "openOnHover"
        static let hoverDelay = "hoverDelay"
        static let haptics = "hapticsEnabled"
        static let swipeGestures = "swipeGestures"
        static let showPercentage = "showPercentage"
        static let transparentCollapsed = "transparentCollapsed"
        static let showPet = "showPet"
        static let outlineCollapsed = "outlineCollapsed"
        static let pinDuringSpaceSwitch = "pinDuringSpaceSwitch"
        static let hudVolume = "hudVolume"
        static let hudBrightness = "hudBrightness"
        static let hudBluetooth = "hudBluetooth"
        static let activityCharging = "activityCharging"
        static let activityNowPlaying = "activityNowPlaying"
        static let showMusic = "showMusic"
        static let showCalendar = "showCalendar"
        static let showShelf = "showShelf"
    }

    enum Default {
        static let openOnHover = true
        static let hoverDelay = 0.3
        static let haptics = true
        static let swipeGestures = true
        static let showPercentage = true
        static let transparentCollapsed = false
        static let showPet = true
        static let outlineCollapsed = true
        static let pinDuringSpaceSwitch = true
        static let hudVolume = true
        static let hudBrightness = true
        static let hudBluetooth = true
        static let activityCharging = true
        static let activityNowPlaying = true
        static let showMusic = true
        static let showCalendar = true
        static let showShelf = true
    }

    /// Call once at launch so `UserDefaults.bool(forKey:)` returns the defaults above for unset keys.
    static func register() {
        UserDefaults.standard.register(defaults: [
            Key.openOnHover: Default.openOnHover, Key.hoverDelay: Default.hoverDelay,
            Key.haptics: Default.haptics, Key.swipeGestures: Default.swipeGestures,
            Key.showPercentage: Default.showPercentage, Key.transparentCollapsed: Default.transparentCollapsed, Key.showPet: Default.showPet, Key.outlineCollapsed: Default.outlineCollapsed, Key.pinDuringSpaceSwitch: Default.pinDuringSpaceSwitch, Key.hudVolume: Default.hudVolume, Key.hudBrightness: Default.hudBrightness,
            Key.hudBluetooth: Default.hudBluetooth, Key.activityCharging: Default.activityCharging,
            Key.activityNowPlaying: Default.activityNowPlaying, Key.showMusic: Default.showMusic,
            Key.showCalendar: Default.showCalendar, Key.showShelf: Default.showShelf,
        ])
    }

    static func bool(_ key: String) -> Bool { UserDefaults.standard.bool(forKey: key) }
    static func double(_ key: String) -> Double { UserDefaults.standard.double(forKey: key) }

    static func isHUDEnabled(for kind: HUDModel.Kind) -> Bool {
        switch kind {
        case .volume: return bool(Key.hudVolume)
        case .brightness: return bool(Key.hudBrightness)
        case .device: return bool(Key.hudBluetooth)
        }
    }
}
