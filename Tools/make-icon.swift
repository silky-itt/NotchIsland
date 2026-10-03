// Generates Resources/AppIcon.icns: swift Tools/make-icon.swift
import AppKit

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func gradient(_ colors: [CGColor]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil)!
}

/// Island attached to the top edge: top corners flare outward, bottom corners are rounded.
func islandPath(rect: CGRect, top: CGFloat, bottom: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let (minX, maxX, minY, maxY) = (rect.minX, rect.maxX, rect.minY, rect.maxY)   // y up: maxY is the top edge
    p.move(to: CGPoint(x: minX - top, y: maxY))
    p.addQuadCurve(to: CGPoint(x: minX, y: maxY - top), control: CGPoint(x: minX, y: maxY))
    p.addLine(to: CGPoint(x: minX, y: minY + bottom))
    p.addQuadCurve(to: CGPoint(x: minX + bottom, y: minY), control: CGPoint(x: minX, y: minY))
    p.addLine(to: CGPoint(x: maxX - bottom, y: minY))
    p.addQuadCurve(to: CGPoint(x: maxX, y: minY + bottom), control: CGPoint(x: maxX, y: minY))
    p.addLine(to: CGPoint(x: maxX, y: maxY - top))
    p.addQuadCurve(to: CGPoint(x: maxX + top, y: maxY), control: CGPoint(x: maxX, y: maxY))
    p.closeSubpath()
    return p
}

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    let ns = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ns
    let ctx = ns.cgContext
    let s = CGFloat(pixels) / 1024
    ctx.scaleBy(x: s, y: s)

    // macOS icon body: 824pt squircle centred in the 1024pt canvas
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 186, cornerHeight: 186, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 28, color: rgb(0x000000, 0.35))
    ctx.addPath(bodyPath); ctx.setFillColor(rgb(0x1A1033)); ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(bodyPath); ctx.clip()

    // Background: deep indigo -> violet -> magenta glow
    ctx.drawLinearGradient(gradient([rgb(0x2B1B6B), rgb(0x6A2FD6), rgb(0xE0468C)]),
                           start: CGPoint(x: 300, y: 924), end: CGPoint(x: 760, y: 100),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    // Soft highlight on the upper half for depth
    ctx.drawRadialGradient(gradient([rgb(0xFFFFFF, 0.22), rgb(0xFFFFFF, 0)]),
                           startCenter: CGPoint(x: 512, y: 880), startRadius: 0,
                           endCenter: CGPoint(x: 512, y: 880), endRadius: 560, options: [])

    // Island (expanded notch) attached to the top edge
    let island = CGRect(x: 222, y: 668, width: 580, height: 256)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 36, color: rgb(0x000000, 0.45))
    ctx.addPath(islandPath(rect: island, top: 34, bottom: 104)); ctx.setFillColor(rgb(0x000000)); ctx.fillPath()
    ctx.restoreGState()

    // Album art
    let art = CGRect(x: 272, y: 700, width: 128, height: 128)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: art, cornerWidth: 30, cornerHeight: 30, transform: nil)); ctx.clip()
    ctx.drawLinearGradient(gradient([rgb(0xFFB347), rgb(0xFF4F7B)]),
                           start: CGPoint(x: art.minX, y: art.maxY), end: CGPoint(x: art.maxX, y: art.minY),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()

    // Track title + artist lines
    ctx.setFillColor(rgb(0xFFFFFF, 0.92))
    ctx.addPath(CGPath(roundedRect: CGRect(x: 428, y: 774, width: 150, height: 22), cornerWidth: 11, cornerHeight: 11, transform: nil)); ctx.fillPath()
    ctx.setFillColor(rgb(0xFFFFFF, 0.38))
    ctx.addPath(CGPath(roundedRect: CGRect(x: 428, y: 732, width: 100, height: 18), cornerWidth: 9, cornerHeight: 9, transform: nil)); ctx.fillPath()

    // Waveform
    ctx.setFillColor(rgb(0x34E27B))
    let barHeights: [CGFloat] = [34, 66, 48, 82, 40]
    for (i, h) in barHeights.enumerated() {
        let x = 624 + CGFloat(i) * 32
        ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: 764 - h / 2 + 12, width: 16, height: h), cornerWidth: 8, cornerHeight: 8, transform: nil))
        ctx.fillPath()
    }

    // Volume HUD pill below the island
    let pill = CGRect(x: 332, y: 470, width: 360, height: 84)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0x000000, 0.4))
    ctx.addPath(CGPath(roundedRect: pill, cornerWidth: 42, cornerHeight: 42, transform: nil))
    ctx.setFillColor(rgb(0x000000)); ctx.fillPath()
    ctx.restoreGState()
    ctx.setFillColor(rgb(0xFFFFFF, 0.25))
    ctx.addPath(CGPath(roundedRect: CGRect(x: 466, y: 502, width: 190, height: 20), cornerWidth: 10, cornerHeight: 10, transform: nil)); ctx.fillPath()
    ctx.setFillColor(rgb(0xFFFFFF))
    ctx.addPath(CGPath(roundedRect: CGRect(x: 466, y: 502, width: 120, height: 20), cornerWidth: 10, cornerHeight: 10, transform: nil)); ctx.fillPath()
    // Speaker glyph: small body + two waves
    ctx.setFillColor(rgb(0xFFFFFF))
    ctx.move(to: CGPoint(x: 366, y: 500)); ctx.addLine(to: CGPoint(x: 384, y: 500)); ctx.addLine(to: CGPoint(x: 406, y: 480))
    ctx.addLine(to: CGPoint(x: 406, y: 544)); ctx.addLine(to: CGPoint(x: 384, y: 524)); ctx.addLine(to: CGPoint(x: 366, y: 524)); ctx.closePath(); ctx.fillPath()
    // Sound waves
    ctx.setStrokeColor(rgb(0xFFFFFF)); ctx.setLineWidth(9); ctx.setLineCap(.round)
    ctx.addArc(center: CGPoint(x: 410, y: 512), radius: 20, startAngle: -.pi / 3, endAngle: .pi / 3, clockwise: false); ctx.strokePath()
    ctx.addArc(center: CGPoint(x: 410, y: 512), radius: 38, startAngle: -.pi / 3, endAngle: .pi / 3, clockwise: false); ctx.strokePath()

    ctx.restoreGState()

    // Hairline edge for definition on light backgrounds
    ctx.addPath(bodyPath); ctx.setStrokeColor(rgb(0xFFFFFF, 0.12)); ctx.setLineWidth(3); ctx.strokePath()

    NSGraphicsContext.current = nil
    return rep.representation(using: .png, properties: [:])!
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset")
try? FileManager.default.removeItem(at: out)
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let files: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in files { try render(pixels: px).write(to: out.appendingPathComponent(name + ".png")) }
print("wrote \(files.count) images to \(out.path)")
