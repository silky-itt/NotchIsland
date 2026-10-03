import AppKit
import SwiftUI

/// Settings window, created on demand.
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var mediaKeys: MediaKeyInterceptor?
    private lazy var window = OnDemandWindow(
        makeContent: { [weak self] in
            guard let mediaKeys = self?.mediaKeys else { return nil }
            return NSHostingController(rootView: SettingsView().environment(mediaKeys))
        },
        configure: { window in
            window.title = "NotchIsland Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
        }
    )

    func configure(mediaKeys: MediaKeyInterceptor) {
        self.mediaKeys = mediaKeys
    }

    func show() {
        window.show()
    }
}
