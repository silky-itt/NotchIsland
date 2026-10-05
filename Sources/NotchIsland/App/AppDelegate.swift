import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NotchPanel?
    private var geometry: NotchGeometry?
    private var panelController: PanelController?
    private var notchSpace: NotchSpace?

    // Features live for the whole app lifetime and update on events
    private let battery = BatteryMonitor()
    private let nowPlaying = NowPlayingMonitor()
    private let calendar = CalendarMonitor()
    private let shelf = ShelfModel()
    private let hud = HUDModel()
    private var volume: VolumeMonitor?
    private var brightness: BrightnessMonitor?
    private var bluetooth: BluetoothMonitor?
    private var mediaKeys: MediaKeyInterceptor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Settings.register()
        // No Dock icon / no menu bar presence
        NSApp.setActivationPolicy(.accessory)
        LaunchAtLogin.enableOnFirstRun()
        nowPlaying.start()
        volume = VolumeMonitor(hud: hud)
        brightness = BrightnessMonitor(hud: hud)
        bluetooth = BluetoothMonitor(hud: hud)
        let mediaKeys = MediaKeyInterceptor(volume: volume!, brightness: brightness!)
        mediaKeys.startIfEnabled()
        self.mediaKeys = mediaKeys
        SettingsWindowController.shared.configure(mediaKeys: mediaKeys)
        ShelfWindowController.shared.configure(shelf: shelf)
        updatePanel()

        #if DEBUG
        // Test hooks: `NotchIsland --open-settings`, `NotchIsland --open-shelf`
        if CommandLine.arguments.contains("--open-settings") { SettingsWindowController.shared.show() }
        if CommandLine.arguments.contains("--open-shelf") { ShelfWindowController.shared.show() }
        #endif

        if calendar.access == .notDetermined {
            Task { await calendar.requestAccess() }
        }

        // Display plugged/unplugged or resolution changed -> reposition
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        nowPlaying.stop()
    }

    @objc private func screensDidChange() {
        updatePanel()
    }

    /// Creates the window once, then only touches it when the geometry really changed
    /// (macOS also posts screen notifications for Space switches, which must not rebuild the UI).
    private func updatePanel() {
        guard let screen = NotchGeometry.targetScreen() else { return }
        let new = NotchGeometry(screen: screen)
        guard new != geometry || panel == nil else { return }

        let notchChanged = new.notchSize != geometry?.notchSize
        geometry = new

        let panel = self.panel ?? NotchPanel()
        if self.panel == nil, Settings.bool(Settings.Key.pinDuringSpaceSwitch) {
            // Read once at launch: moving the window back out of the private Space is not reliable
            let space = NotchSpace()
            space.add(panel)
            notchSpace = space
        }
        self.panel = panel

        if let controller = panelController {
            controller.update(geometry: new)
        } else {
            panelController = PanelController(panel: panel, geometry: new)
        }

        if notchChanged || panel.contentView == nil, let controller = panelController {
            let rootView = NotchView(notchSize: new.notchSize)
                .environment(battery)
                .environment(nowPlaying)
                .environment(calendar)
                .environment(shelf)
                .environment(hud)
                .environment(controller)
                .environment(\.colorScheme, .dark)

            let hostingView = NSHostingView(rootView: rootView)
            // The controller sizes the window; do not let SwiftUI resize it
            hostingView.sizingOptions = []
            panel.contentView = hostingView
        }
        panel.orderFrontRegardless()
    }
}
