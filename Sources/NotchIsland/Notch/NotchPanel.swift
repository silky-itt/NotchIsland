import AppKit

extension Notification.Name {
    static let notchSwipe = Notification.Name("NotchIslandSwipe")
    static let notchSwipeDownKey = "down"
}

/// Transparent borderless window that sits over the notch.
final class NotchPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        // Above the menu bar so it covers the notch area
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        // Visible on every Space, including over full-screen apps
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
    }

    // MARK: - Two-finger swipe (down opens, up closes)

    private var swipeAccumulator: CGFloat = 0
    private var swipeFired = false
    private static let swipeThreshold: CGFloat = 40

    override func sendEvent(_ event: NSEvent) {
        if event.type == .scrollWheel, event.hasPreciseScrollingDeltas { trackSwipe(event) }
        super.sendEvent(event)
    }

    private func trackSwipe(_ event: NSEvent) {
        if event.phase.contains(.began) {
            swipeAccumulator = 0
            swipeFired = false
        }
        guard !swipeFired, !event.phase.isEmpty else { return }

        // Positive = fingers moving down, regardless of the "natural scrolling" setting
        let fingersDown = event.isDirectionInvertedFromDevice ? event.scrollingDeltaY : -event.scrollingDeltaY
        swipeAccumulator += fingersDown
        if abs(swipeAccumulator) > Self.swipeThreshold {
            swipeFired = true
            NotificationCenter.default.post(name: .notchSwipe, object: nil,
                                            userInfo: [Notification.Name.notchSwipeDownKey: swipeAccumulator > 0])
        }
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
