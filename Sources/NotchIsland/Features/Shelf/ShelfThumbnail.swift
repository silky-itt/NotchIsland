import SwiftUI
import UniformTypeIdentifiers

/// Image files show a small preview; everything else shows its Finder icon.
/// The preview is decoded at thumbnail size off the main thread, so large photos cost almost no memory.
struct ShelfThumbnail: View {
    let url: URL
    let size: CGFloat

    @State private var preview: NSImage?

    var body: some View {
        Group {
            if let preview {
                Image(nsImage: preview)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.18))
            } else {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .frame(width: size, height: size)
            }
        }
        .task(id: url) {
            preview = await Self.loadPreview(of: url, maxPixels: size * 2)
        }
    }

    private static func loadPreview(of url: URL, maxPixels: CGFloat) async -> NSImage? {
        await Task.detached(priority: .utility) {
            guard UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true,
                  let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                      kCGImageSourceCreateThumbnailFromImageAlways: true,
                      kCGImageSourceThumbnailMaxPixelSize: maxPixels,
                      kCGImageSourceCreateThumbnailWithTransform: true,
                  ] as CFDictionary)
            else { return nil }
            return NSImage(cgImage: image, size: .zero)
        }.value
    }
}
