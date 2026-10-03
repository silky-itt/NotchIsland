import AppKit
import Observation
import UniformTypeIdentifiers

/// The shelf.
/// - Files dropped from Finder are referenced by path (not copied).
/// - Images that are not files yet (dragged from a browser or a screenshot thumbnail, or pasted) are saved into
///   NotchIsland's own folder, and deleted again when they are removed from the shelf.
/// The list survives restarts; files that no longer exist are dropped on load.
@Observable
@MainActor
final class ShelfModel {
    private(set) var items: [URL] = []

    /// Everything the shelf accepts when dropped
    static let acceptedTypes: [UTType] = [.fileURL, .image, .url]
    /// ~/Library/Application Support/NotchIsland/Shelf
    static let storageFolder = URL.applicationSupportDirectory.appending(path: "NotchIsland/Shelf", directoryHint: .isDirectory)

    private static let defaultsKey = "shelfPaths"

    init() {
        let paths = UserDefaults.standard.stringArray(forKey: Self.defaultsKey) ?? []
        items = paths
            .filter { FileManager.default.fileExists(atPath: $0) }
            .map { URL(fileURLWithPath: $0) }
        removeOrphanedImages()
    }

    // MARK: - Adding

    func add(from providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url, url.isFileURL else { return }
                    Task { @MainActor in self.add(url) }
                }
            } else if let type = provider.registeredContentTypes.first(where: { $0.conforms(to: .image) }) {
                // Image data without a file (browser, screenshot thumbnail...)
                _ = provider.loadDataRepresentation(for: type) { data, _ in
                    guard let data else { return }
                    Task { @MainActor in self.addImage(data, type: type) }
                }
            } else if provider.canLoadObject(ofClass: URL.self) {
                // Last resort: a link straight to an image file
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in await self.downloadImage(from: url) }
                }
            }
        }
    }

    func add(_ url: URL) {
        guard !items.contains(url) else { return }
        items.append(url)
        save()
    }

    /// Adds files or an image from the clipboard. Returns false if there was nothing usable.
    @discardableResult
    func pasteFromClipboard() -> Bool {
        let pasteboard = NSPasteboard.general
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            urls.forEach { add($0) }
            return true
        }
        if let data = pasteboard.data(forType: .png) {
            addImage(data, type: .png)
            return true
        }
        if let data = pasteboard.data(forType: .tiff) {
            addImage(data, type: .tiff)
            return true
        }
        if let image = NSImage(pasteboard: pasteboard), let tiff = image.tiffRepresentation {
            addImage(tiff, type: .tiff)
            return true
        }
        NSSound.beep()
        return false
    }

    // MARK: - Removing

    func remove(_ url: URL) {
        items.removeAll { $0 == url }
        deleteIfOwned(url)
        save()
    }

    func clear() {
        items.forEach(deleteIfOwned)
        items.removeAll()
        save()
    }

    /// True for images NotchIsland saved itself (deleted when removed from the shelf).
    static func isOwned(_ url: URL) -> Bool {
        url.standardizedFileURL.path.hasPrefix(storageFolder.standardizedFileURL.path)
    }

    // MARK: - Private

    private func addImage(_ data: Data, type: UTType) {
        var data = data
        var fileExtension = type.preferredFilenameExtension ?? "png"
        // Apps often hand over huge uncompressed TIFFs; store those as PNG
        if type.conforms(to: .tiff), let png = NSBitmapImageRep(data: data)?.representation(using: .png, properties: [:]) {
            data = png
            fileExtension = "png"
        }

        let folder = Self.storageFolder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let name = "Image \(formatter.string(from: Date()))"
        var url = folder.appending(path: "\(name).\(fileExtension)")
        var counter = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appending(path: "\(name) \(counter).\(fileExtension)")
            counter += 1
        }

        do {
            try data.write(to: url)
            add(url)
        } catch {
            NSLog("NotchIsland: could not save image to the shelf: \(error)")
        }
    }

    private func downloadImage(from url: URL) async {
        // Only links that point at an image file; never fetch ordinary web pages
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true,
              let (data, response) = try? await URLSession.shared.data(from: url),
              let mimeType = response.mimeType,
              let type = UTType(mimeType: mimeType), type.conforms(to: .image)
        else { return }
        addImage(data, type: type)
    }

    private func deleteIfOwned(_ url: URL) {
        guard Self.isOwned(url) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Saved images that are no longer on the shelf (e.g. after a crash) are deleted at launch.
    private func removeOrphanedImages() {
        let saved = (try? FileManager.default.contentsOfDirectory(at: Self.storageFolder, includingPropertiesForKeys: nil)) ?? []
        let kept = Set(items.map { $0.standardizedFileURL.path })
        for url in saved where !kept.contains(url.standardizedFileURL.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func save() {
        UserDefaults.standard.set(items.map(\.path), forKey: Self.defaultsKey)
    }
}
