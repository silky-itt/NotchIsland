import SwiftUI

/// Shelf block in the expanded notch. Clicking it opens the window that lists every file.
struct ShelfView: View {
    @Environment(ShelfModel.self) private var shelf
    let isDropTargeted: Bool

    private let columns = [GridItem(.adaptive(minimum: 36), spacing: 6)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                SectionHeader(title: shelf.items.isEmpty ? "Shelf" : "Shelf · \(shelf.items.count)", systemImage: "tray")
                Spacer()
                HeaderButton(systemImage: "doc.on.clipboard", help: "Paste image or files") { shelf.pasteFromClipboard() }
                if !shelf.items.isEmpty {
                    HeaderButton(systemImage: "trash", help: "Clear shelf") { shelf.clear() }
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(.white.opacity(isDropTargeted ? 0.7 : 0.2))

                if shelf.items.isEmpty {
                    Placeholder(text: "Drop files or images here")
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(shelf.items, id: \.self) { url in
                                ShelfItem(url: url)
                            }
                        }
                        .padding(6)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { ShelfWindowController.shared.show() }
            .help("Click to see every file on the shelf")
        }
    }
}

private struct HeaderButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private struct ShelfItem: View {
    @Environment(ShelfModel.self) private var shelf
    let url: URL

    var body: some View {
        ShelfThumbnail(url: url, size: 32)
            .help(url.lastPathComponent)
            // Drag out to drop into Finder or another app
            .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
            .contextMenu {
                Button("Open") { NSWorkspace.shared.open(url) }
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                Divider()
                Button("Remove from Shelf") { shelf.remove(url) }
            }
    }
}
