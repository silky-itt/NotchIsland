import AppKit

/// A window that is created when shown and destroyed when closed, so it costs no memory while closed.
@MainActor
final class OnDemandWindow {
    private var window: NSWindow?
    private var closeObserver: NSObjectProtocol?
    private let makeContent: () -> NSViewController?
    private let configure: (NSWindow) -> Void

    init(makeContent: @escaping () -> NSViewController?, configure: @escaping (NSWindow) -> Void) {
        self.makeContent = makeContent
        self.configure = configure
    }

    func show() {
        if window == nil { makeWindow() }
        NSApp.activate()   // the app has no Dock icon, so bring it forward explicitly
        window?.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() {
        guard let content = makeContent() else { return }
        let window = NSWindow(contentViewController: content)
        window.isReleasedWhenClosed = false
        configure(window)
        window.center()

        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                if let observer = self?.closeObserver { NotificationCenter.default.removeObserver(observer) }
                self?.closeObserver = nil
                self?.window = nil
            }
        }
        self.window = window
    }
}
