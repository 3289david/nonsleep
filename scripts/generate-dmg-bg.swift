#!/usr/bin/env swift

import AppKit

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let fm = FileManager.default
try? fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

let width = 660
let height = 400

let image = NSImage(size: NSSize(width: width, height: height))
image.lockFocus()

let ctx = NSGraphicsContext.current!.cgContext
let w = CGFloat(width)
let h = CGFloat(height)

// Dark gradient background
let colorSpace = CGColorSpaceCreateDeviceRGB()
let colors = [
    CGColor(red: 0.06, green: 0.06, blue: 0.09, alpha: 1.0),
    CGColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1.0),
]
let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: w/2, y: h), end: CGPoint(x: w/2, y: 0), options: [])

// Subtle grid dots
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.03))
for x in stride(from: 0, to: Int(w), by: 20) {
    for y in stride(from: 0, to: Int(h), by: 20) {
        ctx.fillEllipse(in: CGRect(x: CGFloat(x) - 0.5, y: CGFloat(y) - 0.5, width: 1, height: 1))
    }
}

// Arrow from left to right
let arrowY = h * 0.42
let arrowLeft = w * 0.33
let arrowRight = w * 0.67

ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.15))
ctx.setLineWidth(2)
ctx.setLineCap(.round)

// Arrow line
ctx.move(to: CGPoint(x: arrowLeft, y: arrowY))
ctx.addLine(to: CGPoint(x: arrowRight, y: arrowY))
ctx.strokePath()

// Arrow head
ctx.move(to: CGPoint(x: arrowRight - 10, y: arrowY + 8))
ctx.addLine(to: CGPoint(x: arrowRight, y: arrowY))
ctx.addLine(to: CGPoint(x: arrowRight - 10, y: arrowY - 8))
ctx.strokePath()

// "Drag to Applications" text
let textAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 13, weight: .medium),
    .foregroundColor: NSColor(white: 1.0, alpha: 0.3),
]
let text = NSAttributedString(string: "Drag to Applications", attributes: textAttrs)
let textSize = text.size()
text.draw(at: NSPoint(x: (w - textSize.width) / 2, y: arrowY - 30))

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    print("Failed to generate background")
    exit(1)
}

let outputPath = "\(outputDir)/background.png"
try png.write(to: URL(fileURLWithPath: outputPath))
print("DMG background: \(outputPath)")
