import SwiftUI

/// Expanded content. Only created while hovering, so it costs no memory while collapsed.
struct ExpandedView: View {
    let notchHeight: CGFloat
    let isDropTargeted: Bool

    @AppStorage(Settings.Key.showMusic) private var showMusic = Settings.Default.showMusic
    @AppStorage(Settings.Key.showCalendar) private var showCalendar = Settings.Default.showCalendar
    @AppStorage(Settings.Key.showShelf) private var showShelf = Settings.Default.showShelf

    private enum Panel: Hashable { case music, calendar, shelf }

    private var panels: [Panel] {
        var result: [Panel] = []
        if showMusic { result.append(.music) }
        if showCalendar { result.append(.calendar) }
        if showShelf { result.append(.shelf) }
        return result
    }

    var body: some View {
        VStack(spacing: 8) {
            // Keep the content below the physical notch, which hides the top of the screen
            Color.clear.frame(height: notchHeight - 8)

            HStack(alignment: .top, spacing: 14) {
                if panels.isEmpty {
                    Placeholder(text: "All panels are turned off in Settings")
                }
                ForEach(Array(panels.enumerated()), id: \.element) { index, panel in
                    if index > 0 { divider }
                    content(for: panel)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .foregroundStyle(.white)
    }

    /// Music takes the leftover width; the others are fixed unless music is hidden.
    @ViewBuilder
    private func content(for panel: Panel) -> some View {
        switch panel {
        case .music:
            NowPlayingView().frame(maxWidth: .infinity, alignment: .leading)
        case .calendar:
            CalendarView().frame(minWidth: showMusic ? 150 : 0, maxWidth: showMusic ? 150 : .infinity, alignment: .leading)
        case .shelf:
            ShelfView(isDropTargeted: isDropTargeted).frame(minWidth: showMusic ? 112 : 0, maxWidth: showMusic ? 112 : .infinity)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.12))
            .frame(width: 1)
    }
}
