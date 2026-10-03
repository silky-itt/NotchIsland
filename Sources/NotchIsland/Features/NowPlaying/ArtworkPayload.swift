import AppKit

/// Handles the cover art inside the adapter's JSON lines without wasting memory.
///
/// A line with artwork is hundreds of KB (the cover as base64). Parsing it with `JSONSerialization` would turn all of
/// that into Strings and dictionaries, several full copies at once. The allocator keeps those pages afterwards, so the
/// app grew by ~7 MB on every first track change. Instead the cover is cut out of the raw bytes and decoded straight
/// from them, and only the small remainder of the line goes through the JSON parser.
enum ArtworkPayload {
    private static let key = Data(#""artworkData":""#.utf8)
    private static let quote = UInt8(ascii: "\"")
    private static let backslash = UInt8(ascii: "\\")
    private static let slash = UInt8(ascii: "/")

    /// Splits a JSON line into (the line with the cover replaced by `""`, the decoded cover bytes).
    /// A line without a string `artworkData` is returned untouched.
    static func split(_ line: Data) -> (json: Data, image: Data?) {
        guard let keyRange = line.range(of: key),
              let endQuote = line[keyRange.upperBound...].firstIndex(of: quote)
        else { return (line, nil) }

        // The adapter escapes "/" as "\/"; undo that so the base64 decodes
        let encoded = line[keyRange.upperBound..<endQuote]
        var base64 = Data(count: encoded.count)
        var length = 0
        length = encoded.withUnsafeBytes { (source: UnsafeRawBufferPointer) -> Int in
            base64.withUnsafeMutableBytes { (target: UnsafeMutableRawBufferPointer) -> Int in
                var written = 0
                var i = 0
                while i < source.count {
                    if source[i] == backslash, i + 1 < source.count, source[i + 1] == slash {
                        target[written] = slash
                        i += 2
                    } else {
                        target[written] = source[i]
                        i += 1
                    }
                    written += 1
                }
                return written
            }
        }
        base64.count = length

        var json = Data(line[..<keyRange.upperBound])
        json.append(contentsOf: line[endQuote...])
        return (json, Data(base64Encoded: base64))
    }

    /// Small decoded copy of the cover (64pt on a Retina display). The original bytes are not kept.
    static func thumbnail(from data: Data, maxPixels: CGFloat = 128) -> NSImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceThumbnailMaxPixelSize: maxPixels,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceShouldCache: false,
              ] as CFDictionary)
        else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: image.width / 2, height: image.height / 2))
    }
}
