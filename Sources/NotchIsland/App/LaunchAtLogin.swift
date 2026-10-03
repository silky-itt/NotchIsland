import Foundation
import ServiceManagement

enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("NotchIsland: could not change Launch at Login: \(error)")
        }
    }

    /// Enabled on first run, but only when the app is in /Applications
    /// (avoids registering the temporary build inside the project folder).
    static func enableOnFirstRun() {
        let key = "didSetUpLaunchAtLogin"
        guard Bundle.main.bundlePath.hasPrefix("/Applications/"),
              !UserDefaults.standard.bool(forKey: key)
        else { return }
        set(true)
        UserDefaults.standard.set(true, forKey: key)
    }
}
