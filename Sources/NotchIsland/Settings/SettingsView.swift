import SwiftUI

struct SettingsView: View {
    @Environment(MediaKeyInterceptor.self) private var mediaKeys
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    @AppStorage(Settings.Key.openOnHover) private var openOnHover = Settings.Default.openOnHover
    @AppStorage(Settings.Key.hoverDelay) private var hoverDelay = Settings.Default.hoverDelay
    @AppStorage(Settings.Key.haptics) private var haptics = Settings.Default.haptics
    @AppStorage(Settings.Key.swipeGestures) private var swipeGestures = Settings.Default.swipeGestures
    @AppStorage(Settings.Key.transparentCollapsed) private var transparentCollapsed = Settings.Default.transparentCollapsed
    @AppStorage(Settings.Key.showPet) private var showPet = Settings.Default.showPet
    @AppStorage(Settings.Key.outlineCollapsed) private var outlineCollapsed = Settings.Default.outlineCollapsed
    @AppStorage(Settings.Key.pinDuringSpaceSwitch) private var pinDuringSpaceSwitch = Settings.Default.pinDuringSpaceSwitch
    @AppStorage(Settings.Key.showPercentage) private var showPercentage = Settings.Default.showPercentage
    @AppStorage(Settings.Key.hudVolume) private var hudVolume = Settings.Default.hudVolume
    @AppStorage(Settings.Key.hudBrightness) private var hudBrightness = Settings.Default.hudBrightness
    @AppStorage(Settings.Key.hudBluetooth) private var hudBluetooth = Settings.Default.hudBluetooth
    @AppStorage(Settings.Key.activityCharging) private var activityCharging = Settings.Default.activityCharging
    @AppStorage(Settings.Key.activityNowPlaying) private var activityNowPlaying = Settings.Default.activityNowPlaying
    @AppStorage(Settings.Key.showMusic) private var showMusic = Settings.Default.showMusic
    @AppStorage(Settings.Key.showCalendar) private var showCalendar = Settings.Default.showCalendar
    @AppStorage(Settings.Key.showShelf) private var showShelf = Settings.Default.showShelf

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: {
                        LaunchAtLogin.set($0)
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                ))
                Toggle("Hide the macOS volume & brightness bars", isOn: Binding(
                    get: { mediaKeys.isEnabled },
                    set: { mediaKeys.setEnabled($0) }
                ))
                Text("Off by default, so macOS shows its own bars next to the small notch indicator. Turning it on needs Accessibility permission. If a HUD is turned off below, nothing is shown for it.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Opening") {
                Toggle("Open when hovering", isOn: $openOnHover)
                if openOnHover {
                    SliderRow(title: "Hover delay", value: $hoverDelay, range: 0...1, step: 0.05)
                }
                Toggle("Haptic feedback when opening", isOn: $haptics)
                Toggle("Two-finger swipe: down opens, up closes", isOn: $swipeGestures)
            }

            Section("Appearance") {
                Toggle("Transparent notch when collapsed (experimental)", isOn: $transparentCollapsed)
                Text("Only the real notch stays black; artwork, waveform and levels float over the menu bar. Turn off to go back to the black notch.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Thin outline around the collapsed notch", isOn: $outlineCollapsed)
                Text("The outline disappears while the island is expanded.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Keep the island still when switching desktops", isOn: $pinDuringSpaceSwitch)
                Text("Stops a second notch from sliding across the screen while swiping between desktops or full-screen apps. Quit and reopen NotchIsland to apply.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Shown beside the notch") {
                Toggle("Pet cat on the right (dances to music, happy when charging, sleepy on low battery)", isOn: $showPet)
                Toggle("Show percentage for volume & brightness", isOn: $showPercentage)
                Toggle("Volume", isOn: $hudVolume)
                Toggle("Brightness", isOn: $hudBrightness)
                Toggle("Bluetooth connect / disconnect", isOn: $hudBluetooth)
                Toggle("Charging", isOn: $activityCharging)
                Toggle("Now playing (artwork and waveform)", isOn: $activityNowPlaying)
            }

            Section("Expanded panels") {
                Toggle("Music", isOn: $showMusic)
                Toggle("Calendar", isOn: $showCalendar)
                Toggle("Shelf", isOn: $showShelf)
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 660)
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        LabeledContent(title) {
            HStack {
                Slider(value: $value, in: range, step: step)
                    .frame(width: 170)
                Text(String(format: "%.2f s", value))
                    .monospacedDigit()
                    .frame(width: 52, alignment: .trailing)
            }
        }
    }
}
