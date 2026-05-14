#!/usr/bin/env swift

import AppKit

let sizes: [(Int, String)] = [
    (16, "icon_16x16"),
    (32, "icon_16x16@2x"),
    (32, "icon_32x32"),
    (64, "icon_32x32@2x"),
    (128, "icon_128x128"),
    (256, "icon_128x128@2x"),
    (256, "icon_256x256"),
    (512, "icon_256x256@2x"),
    (512, "icon_512x512"),
    (1024, "icon_512x512@2x"),
]

func drawIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let s = CGFloat(size)
    let ctx = NSGraphicsContext.current!.cgContext

    // Background - dark rounded rect
    let bgRect = CGRect(x: s * 0.05, y: s * 0.05, width: s * 0.9, height: s * 0.9)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: s * 0.2, cornerHeight: s * 0.2, transform: nil)

    // Gradient background
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradColors = [
        CGColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0),
        CGColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0),
    ]
    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradColors as CFArray, locations: [0, 1])!

    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    ctx.drawLinearGradient(gradient, start: CGPoint(x: s/2, y: s), end: CGPoint(x: s/2, y: 0), options: [])
    ctx.restoreGState()

    // Moon crescent
    let moonCenter = CGPoint(x: s * 0.48, y: s * 0.52)
    let moonRadius = s * 0.25

    ctx.saveGState()

    // Moon body (white/light)
    let moonPath = CGMutablePath()
    moonPath.addArc(center: moonCenter, radius: moonRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)

    // Cut out a circle to make crescent
    let cutCenter = CGPoint(x: moonCenter.x + moonRadius * 0.5, y: moonCenter.y + moonRadius * 0.3)
    let cutRadius = moonRadius * 0.8

    ctx.addPath(moonPath)
    ctx.setFillColor(CGColor(red: 0.93, green: 0.95, blue: 1.0, alpha: 1.0))
    ctx.fillPath()

    // Cut the circle by drawing background color over it
    let cutPath = CGMutablePath()
    cutPath.addArc(center: cutCenter, radius: cutRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.addPath(cutPath)

    // Use the background gradient colors
    ctx.setFillColor(CGColor(red: 0.06, green: 0.06, blue: 0.1, alpha: 1.0))
    ctx.fillPath()
    ctx.restoreGState()

    // "ZZZ" text - green, indicating sleep prevention
    let zzFont = NSFont.systemFont(ofSize: s * 0.12, weight: .bold)
    let zzAttrs: [NSAttributedString.Key: Any] = [
        .font: zzFont,
        .foregroundColor: NSColor(red: 0.13, green: 0.77, blue: 0.35, alpha: 1.0),
    ]

    // Strike-through line on Z's
    let z1 = NSAttributedString(string: "Z", attributes: zzAttrs)
    let z2Font = NSFont.systemFont(ofSize: s * 0.09, weight: .bold)
    let z2Attrs: [NSAttributedString.Key: Any] = [
        .font: z2Font,
        .foregroundColor: NSColor(red: 0.13, green: 0.77, blue: 0.35, alpha: 0.7),
    ]
    let z2 = NSAttributedString(string: "Z", attributes: z2Attrs)
    let z3Font = NSFont.systemFont(ofSize: s * 0.07, weight: .bold)
    let z3Attrs: [NSAttributedString.Key: Any] = [
        .font: z3Font,
        .foregroundColor: NSColor(red: 0.13, green: 0.77, blue: 0.35, alpha: 0.5),
    ]
    let z3 = NSAttributedString(string: "Z", attributes: z3Attrs)

    z1.draw(at: NSPoint(x: s * 0.58, y: s * 0.55))
    z2.draw(at: NSPoint(x: s * 0.66, y: s * 0.65))
    z3.draw(at: NSPoint(x: s * 0.72, y: s * 0.72))

    // Red strike-through line across Z's
    ctx.setStrokeColor(CGColor(red: 0.95, green: 0.25, blue: 0.25, alpha: 0.9))
    ctx.setLineWidth(s * 0.02)
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: s * 0.55, y: s * 0.6))
    ctx.addLine(to: CGPoint(x: s * 0.8, y: s * 0.82))
    ctx.strokePath()

    image.unlockFocus()
    return image
}

let iconsetPath = "assets/NonSleep.iconset"
let fm = FileManager.default
try? fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

for (size, name) in sizes {
    let image = drawIcon(size: size)
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    try png.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(name).png"))
    print("Generated \(name).png (\(size)x\(size))")
}

print("Iconset created at \(iconsetPath)")
print("Run: iconutil -c icns \(iconsetPath) -o assets/NonSleep.icns")
