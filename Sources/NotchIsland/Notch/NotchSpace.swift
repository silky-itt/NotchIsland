import AppKit

/// A private window-server Space that sits above every desktop and full-screen Space.
/// Windows placed in it do not slide with the Space-switch animation, so the island stays pinned to the
/// real notch while swiping between desktops (otherwise a second "notch" slides across the screen).
/// Uses private SkyLight calls (exported through CoreGraphics), like DisplayServices for brightness.
@MainActor
final class NotchSpace {
    private let connection = _CGSDefaultConnection()
    private let id: CGSSpaceID

    init() {
        // The flag must be 1, otherwise Finder starts drawing desktop icons in this Space
        id = CGSSpaceCreate(connection, 1, nil)
        CGSSpaceSetAbsoluteLevel(connection, id, Int(Int32.max))
        CGSShowSpaces(connection, [id] as NSArray)
    }

    deinit {
        CGSHideSpaces(connection, [id] as NSArray)
        CGSSpaceDestroy(connection, id)
    }

    func add(_ window: NSWindow) {
        CGSAddWindowsToSpaces(connection, [window.windowNumber] as NSArray, [id] as NSArray)
    }
}

private typealias CGSConnectionID = UInt32
private typealias CGSSpaceID = UInt64

@_silgen_name("_CGSDefaultConnection")
private func _CGSDefaultConnection() -> CGSConnectionID
@_silgen_name("CGSSpaceCreate")
private func CGSSpaceCreate(_ cid: CGSConnectionID, _ flag: Int, _ options: NSDictionary?) -> CGSSpaceID
@_silgen_name("CGSSpaceDestroy")
private func CGSSpaceDestroy(_ cid: CGSConnectionID, _ space: CGSSpaceID)
@_silgen_name("CGSSpaceSetAbsoluteLevel")
private func CGSSpaceSetAbsoluteLevel(_ cid: CGSConnectionID, _ space: CGSSpaceID, _ level: Int)
@_silgen_name("CGSShowSpaces")
private func CGSShowSpaces(_ cid: CGSConnectionID, _ spaces: NSArray)
@_silgen_name("CGSHideSpaces")
private func CGSHideSpaces(_ cid: CGSConnectionID, _ spaces: NSArray)
@_silgen_name("CGSAddWindowsToSpaces")
private func CGSAddWindowsToSpaces(_ cid: CGSConnectionID, _ windows: NSArray, _ spaces: NSArray)
