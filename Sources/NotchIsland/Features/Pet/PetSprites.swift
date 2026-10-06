import CoreGraphics

/// Which pet sits beside the notch (chosen in Settings).
enum PetKind: String, CaseIterable, Identifiable {
    case cat, dog, bunny, panda, frog

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cat: "Cat"
        case .dog: "Dog"
        case .bunny: "Bunny"
        case .panda: "Panda"
        case .frog: "Frog"
        }
    }

    var sprites: PetSprites {
        switch self {
        case .cat: PetSprites.cat
        case .dog: PetSprites.dog
        case .bunny: PetSprites.bunny
        case .panda: PetSprites.panda
        case .frog: PetSprites.frog
        }
    }
}

/// Pixel-art pets, drawn from text grids (one character = one pixel, 15×15). Each pet is built the first time
/// it is shown; each frame is ~1 KB.
/// Columns 12-14 of rows 0-3 are left empty in every pet: that is where the sleepy "z" goes.
struct PetSprites {
    let open: CGImage
    let blink: CGImage
    let happy: CGImage
    let sleepy: CGImage

    private init(base: [String], blink: [Int: String], happy: [Int: String], colors: [Character: UInt32]) {
        let palette = Self.shared.merging(colors) { $1 }
        let closed = Self.replacing(base, rows: blink)
        open = Self.make(base, palette: palette)
        self.blink = Self.make(closed, palette: palette)
        self.happy = Self.make(Self.replacing(base, rows: happy), palette: palette)
        sleepy = Self.make(Self.replacing(closed, rows: Self.zzz(closed)), palette: palette)
    }

    // MARK: - Pets

    /// Sitting cat facing forward, tail curling up on the right
    static let cat = PetSprites(
        base: [
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
        ],
        blink: [5: "KOOOOOOOOOOK...", 6: "KOKKOOOOKKOK..."],
        happy: [5: "KOOKOOOOKOOK...", 6: "KOKOKOOKOKOK...", 7: "KPLLLPPLLLPK..."],
        colors: ["O": 0xF2A65A, "L": 0xFFE3C4]   // ginger fur, cream muzzle and belly
    )

    /// Puppy with floppy ears and its tongue out
    static let dog = PetSprites(
        base: [
            "..KKKKKKKK.....",
            ".KOOOOOOOOK....",
            "KDKOOOOOOKDK...",
            "KDKOOOOOOKDK...",
            "KDOOOOOOOODK...",
            "KDOEWOOEWODK...",
            ".KOEEOOEEOK....",
            ".KOOLKKLOOK....",
            "..KLLPPLLK..KK.",
            "..KKKKKKKK.KOK.",
            "..KOOOOOOK.KOK.",
            ".KOOLLLLOOKKOK.",
            ".KOOLLLLOOOK...",
            ".KOKOOOOKOK....",
            "..KKKKKKKK.....",
        ],
        blink: [5: "KDOOOOOOOODK...", 6: ".KOKKOOKKOK...."],
        happy: [5: "KDOOKOOKOODK...", 6: ".KOKOKKOKOK...."],
        colors: ["O": 0xC68B59, "D": 0x7A4A2A, "L": 0xF5DEC0]   // tan fur, dark ears, light muzzle
    )

    /// White bunny with tall pink ears and a fluffy tail
    static let bunny = PetSprites(
        base: [
            "..KK....KK.....",
            ".KOPK..KPOK....",
            ".KOPK..KPOK....",
            ".KOPKKKKPOK....",
            "KOOOOOOOOOOK...",
            "KOEWOOOOEWOK...",
            "KOEEOOOOEEOK...",
            "KOPOOKKOOPOK...",
            ".KOOOLLOOOK....",
            "..KKKKKKKK.....",
            "..KOOOOOOK.....",
            ".KOOLLLLOOK.KK.",
            ".KOOLLLLOOKLLK.",
            ".KOOKOOKOOOKK..",
            "..KKKKKKKKK....",
        ],
        blink: [5: "KOOOOOOOOOOK...", 6: "KOKKOOOOKKOK..."],
        happy: [5: "KOOKOOOOKOOK...", 6: "KOKOKOOKOKOK..."],
        colors: ["O": 0xF4F1EC, "L": 0xFBE3EA]   // white fur, pinkish belly and teeth
    )

    /// Panda with black ears, eye patches, arms and feet
    static let panda = PetSprites(
        base: [
            ".KK......KK....",
            "KBBK....KBBK...",
            "KBBKKKKKKBBK...",
            "KOOOOOOOOOOK...",
            "KOOOOOOOOOOK...",
            "KOBBOOOOBBOK...",
            "KBWBOOOOBWBK...",
            "KOBBOKKOBBOK...",
            ".KOOOOOOOOK....",
            "..KKKKKKKK.....",
            ".KBBOOOOBBK....",
            ".KBBOOOOBBK....",
            ".KOOOOOOOOK....",
            ".KBBKOOKBBK....",
            "..KKKKKKKK.....",
        ],
        blink: [6: "KBBBOOOOBBBK..."],
        happy: [6: "KBBBOOOOBBBK...", 8: ".KOPOKKOPOK...."],
        colors: ["O": 0xF5F5F5, "B": 0x1E1E1E]   // white fur, black patches
    )

    /// Frog with bulging eyes and a wide smile
    static let frog = PetSprites(
        base: [
            "...............",
            ".KKK....KKK....",
            "KWWEK..KWWEK...",
            "KWEEKKKKWEEK...",
            "KOOOOOOOOOOK...",
            "KPOOOOOOOOPK...",
            "KOKOOOOOOKOK...",
            ".KOKKKKKKOK....",
            "..KOOOOOOK.....",
            ".KOOLLLLOOK....",
            "KOOLLLLLLOOK...",
            "KOOLLLLLLOOK...",
            "KOOOLLLLOOOK...",
            "KOKOOKKOOKOK...",
            ".KKKKKKKKKK....",
        ],
        blink: [2: "KOOOK..KOOOK...", 3: "KKKKKKKKKKKK..."],
        happy: [2: "KOKOK..KOKOK...", 3: "KKOKKKKKKOKK..."],
        colors: ["O": 0x7BC86C, "L": 0xD8F0B0]   // green skin, pale belly
    )

    // MARK: - Drawing

    /// Colours every pet uses; each pet adds its own fur colours on top.
    private static let shared: [Character: UInt32] = [
        "K": 0x2A1B12,   // outline: readable on both the black notch and a light menu bar
        "P": 0xF48FB1,   // pink ears, nose, blush, tongue
        "E": 0x1A1A1A,   // eyes
        "W": 0xFFFFFF,   // eye highlight
        "Z": 0xCFE3FF,   // "z" when sleepy
    ]

    /// Writes a small "z" into the top-right corner (columns 12-14 of rows 0-3).
    private static func zzz(_ rows: [String]) -> [Int: String] {
        let letter = ["ZZZ", "..Z", ".Z.", "ZZZ"]
        var result: [Int: String] = [:]
        for (index, part) in letter.enumerated() {
            result[index] = String(rows[index].prefix(12)) + part
        }
        return result
    }

    private static func replacing(_ rows: [String], rows replacements: [Int: String]) -> [String] {
        var result = rows
        for (index, row) in replacements { result[index] = row }
        return result
    }

    private static func make(_ rows: [String], palette: [Character: UInt32]) -> CGImage {
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
