#if DEBUG
import SwiftUI

// Live preview in Xcode: open Package.swift -> open this file -> Editor > Canvas (⌥⌘↩).
// Data is real (battery, calendar...) so it looks like the running app; without the adapter, music shows a placeholder.

private struct PreviewHost<Content: View>: View {
    @ViewBuilder let content: Content
    @State private var battery = BatteryMonitor()
    @State private var nowPlaying = NowPlayingMonitor()
    @State private var calendar = CalendarMonitor()
    @State private var shelf = ShelfModel()
    @State private var hud = HUDModel()

    var body: some View {
        content
            .environment(battery)
            .environment(nowPlaying)
            .environment(calendar)
            .environment(shelf)
            .environment(hud)
            .environment(\.colorScheme, .dark)
    }
}

#Preview("Expanded") {
    PreviewHost {
        let size = NotchGeometry.expandedSize
        ExpandedView(notchHeight: 32, isDropTargeted: false)
            .padding(.horizontal, 32)
            .padding(.bottom, 14)
            .frame(width: size.width, height: size.height)
            .background(NotchShape(topRadius: 14, bottomRadius: 28).fill(.black))
            .padding(20)
            .background(.gray.opacity(0.3))
    }
}

#Preview("Collapsed + HUD") {
    PreviewHost {
        HStack(spacing: 24) {
            let volume = HUDModel.Event(kind: .volume(muted: false), value: 0.6)
            let brightness = HUDModel.Event(kind: .brightness, value: 0.8)
            let device = HUDModel.Event(kind: .device(name: "AirPods Pro", connected: true), value: 0)
            ForEach([volume, brightness, device], id: \.kind) { event in
                HStack {
                    HUDActivity.Leading(event: event)
                    Spacer()
                    HUDActivity.Trailing(event: event)
                }
                .padding(.horizontal, 12)
                .frame(width: 200 + HUDActivity.sideWidth(for: event) * 2 - 100, height: 32)
                .background(NotchShape(topRadius: 6, bottomRadius: 12).fill(.black))
            }
        }
        .padding(20)
        .background(.gray.opacity(0.3))
    }
}
#endif
