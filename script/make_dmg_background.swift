#!/usr/bin/env swift

// Draws the DMG window background: an arrow pointing from where the app icon
// sits to where the Applications alias sits, and a line of text under them.
// Regenerates both scales and combines them into the multi-representation TIFF
// that Finder needs to pick the right one on a Retina display.
//
//   ./script/make_dmg_background.swift
//
// Icon positions are duplicated in script/dmg/appdmg.json — the arrow has to
// point between the icons, and nothing checks that for us.

import AppKit
import CoreText
import Foundation

let windowSize = CGSize(width: 640, height: 400)
let iconCenterY = 190.0          // from the top, matching appdmg.json
let appIconX = 160.0
let applicationsIconX = 480.0
let iconRadius = 64.0

let outputDirectory = URL(fileURLWithPath: "script/dmg", isDirectory: true)

func drawBackground(scale: CGFloat) -> CGImage? {
    let width = Int(windowSize.width * scale)
    let height = Int(windowSize.height * scale)

    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return nil
    }

    context.scaleBy(x: scale, y: scale)

    // CoreGraphics puts the origin at the bottom; every measurement here is
    // from the top, the way the window is described.
    func flipped(_ y: Double) -> Double { windowSize.height - y }

    context.setFillColor(CGColor(red: 0.957, green: 0.957, blue: 0.965, alpha: 1))
    context.fill(CGRect(origin: .zero, size: windowSize))

    // The arrow: a shaft between the two icons, stopping short of both so it
    // never touches an icon, plus a solid head.
    let arrowColor = CGColor(red: 0.72, green: 0.72, blue: 0.76, alpha: 1)
    // Measured from the icon edge, not its centre: `iconRadius` is half of the
    // 128pt icon, so the shaft starts a clear gap away from the artwork.
    let gap = 26.0
    let shaftStart = appIconX + iconRadius + gap
    let shaftEnd = applicationsIconX - iconRadius - gap
    let headLength = 26.0
    let headHalfHeight = 13.0
    let y = flipped(iconCenterY)

    context.setStrokeColor(arrowColor)
    context.setLineWidth(6)
    context.setLineCap(.round)
    context.move(to: CGPoint(x: shaftStart, y: y))
    context.addLine(to: CGPoint(x: shaftEnd - headLength + 4, y: y))
    context.strokePath()

    context.setFillColor(arrowColor)
    context.move(to: CGPoint(x: shaftEnd, y: y))
    context.addLine(to: CGPoint(x: shaftEnd - headLength, y: y + headHalfHeight))
    context.addLine(to: CGPoint(x: shaftEnd - headLength, y: y - headHalfHeight))
    context.closePath()
    context.fillPath()

    let caption = "Drag MacYaD to Applications"
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 15, weight: .regular),
        .foregroundColor: NSColor(calibratedRed: 0.42, green: 0.42, blue: 0.46, alpha: 1)
    ]
    let line = CTLineCreateWithAttributedString(
        NSAttributedString(string: caption, attributes: attributes)
    )
    let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
    context.textPosition = CGPoint(
        x: (windowSize.width - bounds.width) / 2,
        y: flipped(iconCenterY + iconRadius + 58)
    )
    CTLineDraw(line, context)

    return context.makeImage()
}

func write(_ image: CGImage, to url: URL) throws {
    let bitmap = NSBitmapImageRep(cgImage: image)
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "make_dmg_background", code: 1)
    }
    try data.write(to: url)
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for scale in [1.0, 2.0] as [CGFloat] {
    guard let image = drawBackground(scale: scale) else {
        FileHandle.standardError.write(Data("error: could not draw the background\n".utf8))
        exit(1)
    }

    let name = scale == 1 ? "background.png" : "background@2x.png"
    try write(image, to: outputDirectory.appendingPathComponent(name))
    print("wrote \(outputDirectory.appendingPathComponent(name).path)")
}

// Finder reads one file and picks the representation matching the display, so
// the two PNGs have to become a single TIFF.
let tiffutil = Process()
tiffutil.executableURL = URL(fileURLWithPath: "/usr/bin/tiffutil")
tiffutil.arguments = [
    "-cathidpicheck",
    outputDirectory.appendingPathComponent("background.png").path,
    outputDirectory.appendingPathComponent("background@2x.png").path,
    "-out",
    outputDirectory.appendingPathComponent("background.tiff").path
]
try tiffutil.run()
tiffutil.waitUntilExit()

guard tiffutil.terminationStatus == 0 else {
    FileHandle.standardError.write(Data("error: tiffutil failed\n".utf8))
    exit(1)
}

print("wrote \(outputDirectory.appendingPathComponent("background.tiff").path)")
