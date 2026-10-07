import CoreGraphics
import Foundation

/// Which pet sits beside the notch (chosen in Settings, stored by `id`).
struct PetKind: Identifiable, Hashable {
    let id: String
    let title: String
    private let load: () -> PetSprites

    var sprites: PetSprites { load() }

    private init(_ id: String, _ title: String, _ load: @escaping () -> PetSprites) {
        self.id = id
        self.title = title
        self.load = load
    }

    static func == (lhs: PetKind, rhs: PetKind) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    static let builtIn: [PetKind] = [
        PetKind("cat", "Cat") { PetSprites.cat },
        PetKind("dog", "Dog") { PetSprites.dog },
        PetKind("bunny", "Bunny") { PetSprites.bunny },
        PetKind("panda", "Panda") { PetSprites.panda },
        PetKind("frog", "Frog") { PetSprites.frog },
        PetKind("fox", "Fox") { PetSprites.fox },
        PetKind("penguin", "Penguin") { PetSprites.penguin },
        PetKind("chick", "Chick") { PetSprites.chick },
        PetKind("ghost", "Ghost") { PetSprites.ghost },
        PetKind("robot", "Robot") { PetSprites.robot },
        PetKind("slime", "Slime") { PetSprites.slime },
    ]

    /// Extra pets drawn by the user, read once at launch from `customFolder`. They stay on this Mac:
    /// they are not part of the source code or of a release build.
    static let custom: [PetKind] = loadCustom()

    static var all: [PetKind] { builtIn + custom }

    /// The pet stored in Settings, or the cat if it no longer exists (e.g. its custom file was removed).
    static func named(_ id: String) -> PetKind { all.first { $0.id == id } ?? builtIn[0] }

    /// ~/Library/Application Support/NotchIsland/Pets — one JSON file per pet:
    /// `{"title": "…", "base": [15 to 24 rows, each as long as there are rows], "blink": {"5": "row"}, "happy": {"5": "row"},
    ///   "colors": {"O": "#F2A65A"}}`. Same grid rules as the built-in pets below.
    static let customFolder = URL.applicationSupportDirectory.appending(path: "NotchIsland/Pets", directoryHint: .isDirectory)

    private struct CustomFile: Decodable {
        let title: String
        let base: [String]
        let blink: [String: String]
        let happy: [String: String]
        let colors: [String: String]
    }

    private static func loadCustom() -> [PetKind] {
        let files = (try? FileManager.default.contentsOfDirectory(at: customFolder, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      let file = try? JSONDecoder().decode(CustomFile.self, from: data),
                      let sprites = PetSprites(custom: file.base, blink: file.blink, happy: file.happy, colors: file.colors)
                else { return nil }   // a broken file is skipped instead of crashing the app
                return PetKind("custom:" + url.deletingPathExtension().lastPathComponent, file.title) { sprites }
            }
    }
}

/// Pixel-art pets, drawn from text grids (one character = one pixel, 15×15). Each pet is built the first time
/// it is shown; each frame is ~1 KB.
/// The last 3 columns of rows 0-3 are left empty in every pet: that is where the sleepy "z" goes.
struct PetSprites {
    let open: CGImage
    let blink: CGImage
    let happy: CGImage
    let sleepy: CGImage

    /// A user-drawn pet from JSON; nil if the grid is not square (15×15 up to 24×24) or a colour is not a hex value.
    init?(custom base: [String], blink: [String: String], happy: [String: String], colors: [String: String]) {
        let size = base.count
        guard (15...24).contains(size) else { return nil }
        func rows(_ raw: [String: String]) -> [Int: String]? {
            var result: [Int: String] = [:]
            for (key, row) in raw {
                guard let index = Int(key), (0..<size).contains(index), row.count == size else { return nil }
                result[index] = row
            }
            return result
        }
        var palette: [Character: UInt32] = [:]
        for (key, value) in colors {
            guard key.count == 1, let hex = UInt32(value.trimmingCharacters(in: ["#"]), radix: 16) else { return nil }
            palette[Character(key)] = hex
        }
        guard base.count == size, base.allSatisfy({ $0.count == size }),
              let blink = rows(blink), let happy = rows(happy) else { return nil }
        self.init(base: base, blink: blink, happy: happy, colors: palette)
    }

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

    /// Writes a small "z" into the top-right corner (last 3 columns of rows 0-3).
    private static func zzz(_ rows: [String]) -> [Int: String] {
        let letter = ["ZZZ", "..Z", ".Z.", "ZZZ"]
        var result: [Int: String] = [:]
        for (index, part) in letter.enumerated() {
            result[index] = String(rows[index].prefix(rows[index].count - 3)) + part
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
