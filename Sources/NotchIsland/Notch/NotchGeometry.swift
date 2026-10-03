import AppKit

/// Computes the notch size and where things sit on screen.
struct NotchGeometry: Equatable {
    /// Size of the expanded island.
    static let expandedSize = CGSize(width: 600, height: 180)
    /// Used when the display has no notch
    static let fallbackNotchSize = CGSize(width: 200, height: 32)
    /// Extra room around the shape inside the window, so the spring's overshoot is never clipped.
    /// Keep it small: the window swallows clicks everywhere it covers.
    static let windowSideMargin: CGFloat = 8
    static let windowBottomMargin: CGFloat = 6
    /// The collapsed shape is wider than the notch by its two flared top corners
    static let collapsedFlare: CGFloat = 12

    /// Last real notch measured on the built-in display. macOS can briefly report no notch while Spaces
    /// or full-screen apps are changing; reusing this keeps the shape from jumping to the fallback size.
    private static var lastKnownNotch: CGSize?

    let notchSize: CGSize
    let screenFrame: CGRect

    init(screen: NSScreen) {
        let frame = screen.frame
        let topInset = screen.safeAreaInsets.top

        if topInset > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let measured = CGSize(width: frame.width - left.width - right.width, height: topInset)
            if screen.isBuiltIn { Self.lastKnownNotch = measured }
            notchSize = measured
        } else if screen.isBuiltIn, let known = Self.lastKnownNotch {
            notchSize = known
        } else {
            notchSize = Self.fallbackNotchSize
        }
        screenFrame = frame
    }

    /// Size of the shape when collapsed and idle: exactly the notch plus its flares.
    var collapsedSize: CGSize {
        CGSize(width: notchSize.width + Self.collapsedFlare, height: notchSize.height)
    }

    /// Where a shape of `size` is drawn: centred on the screen, flush with the top edge.
    func contentRect(for size: CGSize) -> CGRect {
        CGRect(x: screenFrame.midX - size.width / 2, y: screenFrame.maxY - size.height,
               width: size.width, height: size.height)
    }

    /// Window frame that hugs a shape of `size` (plus the small margins).
    func windowFrame(for size: CGSize) -> CGRect {
        let width = size.width + Self.windowSideMargin * 2
        let height = size.height + Self.windowBottomMargin
        return CGRect(x: screenFrame.midX - width / 2, y: screenFrame.maxY - height, width: width, height: height)
    }

    /// Prefers the display with a notch, then the built-in display, then the main display.
    static func targetScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
            ?? NSScreen.screens.first { $0.isBuiltIn }
            ?? NSScreen.main
    }
}

private extension NSScreen {
    var isBuiltIn: Bool {
        guard let id = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return false }
        return CGDisplayIsBuiltin(id) != 0
    }
}
