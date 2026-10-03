import AppKit
import SwiftUI

/// The "all files" window that opens when the shelf is clicked. Created on demand.
@MainActor
final class ShelfWindowController {
    static let shared = ShelfWindowController()

    private var shelf: ShelfModel?
    private lazy var window = OnDemandWindow(
        makeContent: { [weak self] in
            guard let shelf = self?.shelf else { return nil }
            let controller = NSHostingController(rootView: ShelfBrowserView().environment(shelf))
            controller.sizingOptions = [.minSize]   // keep the initial size below instead of shrinking to fit
            return controller
        },
        configure: { window in
            window.title = "Shelf"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 520, height: 420))
        }
    )

    func configure(shelf: ShelfModel) {
        self.shelf = shelf
    }

    func show() {
        window.show()
    }
}

struct ShelfBrowserView: View {
    @Environment(ShelfModel.self) private var shelf
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            if shelf.items.isEmpty {
                ContentUnavailableView("The shelf is empty", systemImage: "tray",
                                       description: Text("Drop files or images on the notch or into this window."))
            } else {
                List {
                    ForEach(shelf.items, id: \.self) { url in
                        ShelfRow(url: url)
                    }
                }
            }

            Divider()
            HStack {
                Text(shelf.items.count == 1 ? "1 item" : "\(shelf.items.count) items")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Paste") { shelf.pasteFromClipboard() }
                Button("Clear All", role: .destructive) { shelf.clear() }
                    .disabled(shelf.items.isEmpty)
            }
            .padding(10)
        }
        .frame(minWidth: 420, minHeight: 280)
        .onDrop(of: ShelfModel.acceptedTypes, isTargeted: $isDropTargeted) { providers in
            shelf.add(from: providers)
            return true
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 8).strokeBorder(Color.accentColor, lineWidth: 3).padding(4)
            }
        }
    }
}

private struct ShelfRow: View {
    @Environment(ShelfModel.self) private var shelf
    let url: URL

    var body: some View {
        HStack(spacing: 10) {
            ShelfThumbnail(url: url, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button { NSWorkspace.shared.open(url) } label: { Image(systemName: "arrow.up.forward.app") }
                .help("Open")
            Button { NSWorkspace.shared.activateFileViewerSelecting([url]) } label: { Image(systemName: "folder") }
                .help("Show in Finder")
            Button { shelf.remove(url) } label: { Image(systemName: "xmark.circle.fill") }
                .help(ShelfModel.isOwned(url) ? "Remove from Shelf (deletes this saved image)" : "Remove from Shelf")
        }
        .buttonStyle(.borderless)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        // Drag a row out to drop the file somewhere else; double-click to open
        .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
        .onTapGesture(count: 2) { NSWorkspace.shared.open(url) }
    }

    private var detail: String {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { $0 }
        let sizeText = size.map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file) } ?? "–"
        let place = ShelfModel.isOwned(url) ? "Saved by NotchIsland" : url.deletingLastPathComponent().path
        return "\(sizeText) · \(place)"
    }
}
