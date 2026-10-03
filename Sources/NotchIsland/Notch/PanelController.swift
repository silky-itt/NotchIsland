import AppKit
import Darwin
import Observation

/// Keeps the notch window from getting in the way of the rest of the screen.
///
/// 1. The window hugs the shape that is currently drawn. It grows *before* the shape does (so animations are
///    never clipped) and shrinks only after the shape has finished shrinking.
/// 2. The window only receives mouse events while the pointer is over the part that is meant to be interactive:
///    the notch body when collapsed, the whole island when expanded. Everywhere else (including the side
///    "wings" that show artwork, volume, charging...) clicks pass straight through to the menu bar or windows below.
///
/// Because the window is click-through most of the time, hover is detected here from mouse events instead of
/// SwiftUI's `onHover`.
@MainActor
@Observable
final class PanelController {
    /// True while the pointer is over the interactive part (drives hover-to-open).
    private(set) var isPointerInside = false

    @ObservationIgnored private let panel: NSPanel
    @ObservationIgnored private var geometry: NotchGeometry
    @ObservationIgnored private var contentSize: CGSize
    @ObservationIgnored private var isExpanded = false
    @ObservationIgnored private var shrinkTask: Task<Void, Never>?
    @ObservationIgnored private var monitors: [Any] = []

    /// How long the window stays large after the shape shrinks, so the close animation can finish.
    private static let shrinkDelay: Duration = .milliseconds(900)

    init(panel: NSPanel, geometry: NotchGeometry) {
        self.panel = panel
        self.geometry = geometry
        contentSize = geometry.collapsedSize

        panel.acceptsMouseMovedEvents = true
        panel.ignoresMouseEvents = true
        panel.setFrame(geometry.windowFrame(for: contentSize), display: true)

        // Moves, and drags (a file dragged onto the notch only produces drag events).
        // Global monitors see events meant for other apps; local ones see events delivered to our own window.
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .leftMouseUp]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.evaluate() }
        }) { monitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.evaluate() }
            return event
        }) { monitors.append(local) }
    }

    deinit {
        monitors.forEach { NSEvent.removeMonitor($0) }
    }

    /// The screen layout changed (display plugged/unplugged, resolution...).
    func update(geometry: NotchGeometry) {
        self.geometry = geometry
        shrinkTask?.cancel()
        panel.setFrame(geometry.windowFrame(for: contentSize), display: true)
        evaluate()
    }

    /// Call right before an expand animation starts, so the window is already big enough.
    func prepareToExpand() {
        contentSizeChanged(NotchGeometry.expandedSize, isExpanded: true)
    }

    /// The SwiftUI shape changed size (expand/collapse, or side activity appearing/disappearing).
    func contentSizeChanged(_ size: CGSize, isExpanded: Bool) {
        contentSize = size
        self.isExpanded = isExpanded

        let target = geometry.windowFrame(for: size)
        let union = panel.frame.union(target)

        shrinkTask?.cancel()
        if union != panel.frame { panel.setFrame(union, display: false) }   // grow now
        if union != target {
            shrinkTask = Task {                                              // shrink later
                try? await Task.sleep(for: Self.shrinkDelay)
                guard !Task.isCancelled else { return }
                panel.setFrame(geometry.windowFrame(for: contentSize), display: true)
                // The expanded UI is gone now: hand memory the allocator kept from it back to the system
                malloc_zone_pressure_relief(nil, 0)
            }
        }
        evaluate()
    }

    // MARK: - Pointer

    /// The part of the screen that should react to the mouse.
    /// Padded a little: the pointer is often pushed against the very top edge (y == maxY), which `CGRect.contains` excludes.
    private var interactiveRect: CGRect {
        let rect = isExpanded ? geometry.contentRect(for: contentSize) : geometry.contentRect(for: geometry.collapsedSize)
        return rect.insetBy(dx: -2, dy: -2)
    }

    private func evaluate() {
        let location = NSEvent.mouseLocation
        // While dragging something onto a collapsed notch, the whole visible shape (wings included) accepts the drop
        let isDragging = NSEvent.pressedMouseButtons & 1 != 0
        let rect = (isDragging && !isExpanded) ? panel.frame : interactiveRect
        let inside = rect.contains(location)

        if inside != isPointerInside { isPointerInside = inside }
        let shouldIgnore = !inside
        if panel.ignoresMouseEvents != shouldIgnore { panel.ignoresMouseEvents = shouldIgnore }
    }
}
