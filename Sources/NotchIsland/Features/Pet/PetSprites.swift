import CoreGraphics

/// Which pet sits beside the notch (chosen in Settings).
enum PetKind: String, CaseIterable, Identifiable {
    case cat, dog, bunny, panda, frog, fox, penguin, chick, ghost, robot, slime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cat: "Cat"
        case .dog: "Dog"
        case .bunny: "Bunny"
        case .panda: "Panda"
        case .frog: "Frog"
        case .fox: "Fox"
        case .penguin: "Penguin"
        case .chick: "Chick"
        case .ghost: "Ghost"
        case .robot: "Robot"
        case .slime: "Slime"
        }
    }

    var sprites: PetSprites {
        switch self {
        case .cat: PetSprites.cat
        case .dog: PetSprites.dog
        case .bunny: PetSprites.bunny
        case .panda: PetSprites.panda
        case .frog: PetSprites.frog
        case .fox: PetSprites.fox
        case .penguin: PetSprites.penguin
        case .chick: PetSprites.chick
        case .ghost: PetSprites.ghost
        case .robot: PetSprites.robot
        case .slime: PetSprites.slime
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

    /// Fox with a white face and a bushy, white-tipped tail
    static let fox = PetSprites(
        base: [
            ".K........K....",
            ".KK......KK....",
            ".KDK....KDK....",
            ".KOOKKKKOOK....",
            "KOOOOOOOOOOK...",
            "KOEWOOOOEWOK...",
            "KLEELLLLEELK...",
            ".KLLLKKLLLK....",
            "..KLLLLLLK..KK.",
            "..KKKKKKKK.KOOK",
            "..KOOOOOOK.KOOK",
            ".KOLLLLLOOKKOLK",
            ".KOLLLLLOOOKLLK",
            ".KOOKOOKOOOOKK.",
            "..KKKKKKKKKK...",
        ],
        blink: [5: "KOOOOOOOOOOK...", 6: "KLKKLLLLKKLK..."],
        happy: [5: "KOOKOOOOKOOK...", 6: "KLKLKLLKLKLK..."],
        colors: ["O": 0xF07A2A, "L": 0xFFF4E6, "D": 0xB4541A]   // orange fur, white face, darker ears
    )

    /// Penguin with flippers, a yellow beak and yellow feet
    static let penguin = PetSprites(
        base: [
            "...............",
            "...KKKKKK......",
            "..KBBBBBBK.....",
            ".KBBBBBBBBK....",
            ".KBLLBBLLBK....",
            ".KLEWLLEWLK....",
            ".KLLLYYLLLK....",
            "KBKLLLLLLKBK...",
            "KBKLLLLLLKBK...",
            "KBKLLLLLLKBK...",
            "KBKLLLLLLKBK...",
            ".KKLLLLLLKK....",
            "..KBLLLLBK.....",
            "..KYYKKYYK.....",
            "..KKK..KKK.....",
        ],
        blink: [5: ".KLKKLLKKLK...."],
        happy: [5: ".KLKKLLKKLK....", 6: ".KPLLYYLLPK...."],
        colors: ["B": 0x2B2D42, "L": 0xF8F8F8, "Y": 0xF5A623]   // navy back, white front, yellow beak and feet
    )

    /// Round yellow chick with a little tuft
    static let chick = PetSprites(
        base: [
            "...............",
            "......KK.......",
            ".....KYK.......",
            "...KKKYYKK.....",
            "..KYYYYYYYYK...",
            ".KYYEYYYYEYYK..",
            ".KYPYYOOYYPYK..",
            ".KYYYYYYYYYYK..",
            "KYKYYYYYYYYKYK.",
            "KYKYYYYYYYYKYK.",
            ".KKYYYYYYYYKK..",
            "..KYYYYYYYYK...",
            "...KKKKKKKK....",
            "....OO..OO.....",
            "...............",
        ],
        blink: [5: ".KYKKYYYYKKYK.."],
        happy: [5: ".KYKKYYYYKKYK..", 6: ".KPPYYOOYYPPK.."],
        colors: ["Y": 0xFFD43B, "O": 0xF59F00]   // yellow down, orange beak and feet
    )

    /// Little ghost with a wavy hem
    static let ghost = PetSprites(
        base: [
            "...............",
            "...KKKKKK......",
            "..KGGGGGGK.....",
            ".KGGGGGGGGK....",
            "KGGGGGGGGGGK...",
            "KGGEGGGGEGGK...",
            "KGGEGGGGEGGK...",
            "KGPGGKKGGPGK...",
            "KGGGGGGGGGGK...",
            "KGGGGGGGGGGK...",
            "KGGGGGGGGGGK...",
            "KGGGGGGGGGGK...",
            "KGGGGGGGGGGK...",
            "KGK.KGGK.KGK...",
            ".K...KK...K....",
        ],
        blink: [5: "KGGGGGGGGGGK...", 6: "KGEEGGGGEEGK..."],
        happy: [6: "KGEGEGGEGEGK..."],
        colors: ["G": 0xF1F3FF]   // pale body
    )

    /// Small robot with an antenna light and a glowing visor
    static let robot = PetSprites(
        base: [
            ".....RR........",
            ".....KK........",
            "..KKKKKKKK.....",
            ".KSSSSSSSSK....",
            ".KSKKKKKKSK....",
            ".KSKCKKCKSK....",
            ".KSKKKKKKSK....",
            ".KSSSSSSSSK....",
            ".KSSKKKKSSK....",
            "..KKKKKKKK.....",
            "KKSSSSSSSSKK...",
            "KSKSRSSCSKSK...",
            "KKKSSSSSSKKK...",
            "...KSKKSK......",
            "...KKKKKK......",
        ],
        blink: [5: ".KSKKKKKKSK...."],
        happy: [4: ".KSKCKKCKSK....", 5: ".KSCKCCKCSK...."],
        colors: ["S": 0xAEB8C4, "C": 0x4DD8FF, "R": 0xFF4D4D]   // steel body, cyan eyes, red lights
    )

    /// Bouncy blue slime
    static let slime = PetSprites(
        base: [
            "...............",
            "...............",
            "...............",
            "...............",
            "...............",
            "....KKKK.......",
            "..KKMMMMKK.....",
            ".KMWMMMMMMK....",
            "KMWMMMMMMMMK...",
            "KMMEWMMEWMMK...",
            "KMMEEMMEEMMK...",
            "KMMMMKKMMMMK...",
            "KMMMMMMMMMMMK..",
            "KMMMMMMMMMMMK..",
            ".KKKKKKKKKKK...",
        ],
        blink: [9: "KMMMMMMMMMMK...", 10: "KMMKKMMKKMMK..."],
        happy: [9: "KMMMKMMMKMMK...", 10: "KMMKMKMKMKMK..."],
        colors: ["M": 0x7DD3FC]   // light blue
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
