import CoreGraphics

/// Pixel-art cat, drawn from text grids (one character = one pixel, 15×15). Built once; each frame is ~1 KB.
enum PetSprites {
    static let open = make(base)
    static let blink = make(replacing(base, rows: [5: "KOOOOOOOOOOK...", 6: "KOKKOOOOKKOK..."]))
    static let happy = make(replacing(base, rows: [5: "KOOKOOOOKOOK...", 6: "KOKOKOOKOKOK...", 7: "KPLLLPPLLLPK..."]))
    static let sleepy = make(replacing(base, rows: [
        0: ".K........K.ZZZ", 1: ".KK......KK...Z", 2: ".KPK....KPK..Z.", 3: ".KOOKKKKOOK.ZZZ",
        5: "KOOOOOOOOOOK...", 6: "KOKKOOOOKKOK...",
    ]))

    /// Sitting cat facing forward, tail curling up on the right
    private static let base = [
        ".K........K....",
        ".KK......KK....",
        ".KPK....KPK....",
        ".KOOKKKKOOK....",
        "KOOOOOOOOOOK...",
        "KOEWOOOOEWOK...",
        "KOEEOOOOEEOK...",
        "KOLLLPPLLLOK...",
        ".KLLLLLLLLK..K.",
        "..KKKKKKKK..KOK",
        "..KOOOOOOK..KOK",
        ".KOLLLLLOOK.KOK",
        ".KOLLLLLOOKKOK.",
        ".KOOKOOKOOOOK..",
        "..KKKKKKKKKK...",
    ]

    private static let palette: [Character: UInt32] = [
        "K": 0x2A1B12,   // outline: readable on both the black notch and a light menu bar
        "O": 0xF2A65A,   // ginger fur
        "L": 0xFFE3C4,   // cream muzzle and belly
        "P": 0xF48FB1,   // pink ears, nose, blush
        "E": 0x1A1A1A,   // eyes
        "W": 0xFFFFFF,   // eye highlight
        "Z": 0xCFE3FF,   // "z" when sleepy
    ]

    private static func replacing(_ rows: [String], rows replacements: [Int: String]) -> [String] {
        var result = rows
        for (index, row) in replacements { result[index] = row }
        return result
    }

    private static func make(_ rows: [String]) -> CGImage {
        let size = rows.count
        let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        for (y, row) in rows.enumerated() {
            for (x, character) in row.enumerated() {
                guard let hex = palette[character] else { continue }
                context.setFillColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                                     blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
                context.fill(CGRect(x: x, y: size - 1 - y, width: 1, height: 1))   // row 0 is the top
            }
        }
        return context.makeImage()!
    }
}
