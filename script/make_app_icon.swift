#!/usr/bin/env swift
// Regenerates AppIcon.appiconset from its own 1024px master.
//
// macOS icons must leave transparent margins: the icon body occupies 824x824
// inside a 1024x1024 canvas. A full-bleed icon renders larger than every other
// app in the Dock and overlaps the running indicator dot.
//
// The script measures the opaque bounding box, so running it twice is a no-op.
//
// Usage: swift script/make_app_icon.swift [appiconset-dir]

import AppKit
import CoreGraphics
import Foundation

let canvas = 1024.0
let body = 824.0

let setDirectory = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Macyad/Resources/Assets.xcassets/AppIcon.appiconset"
let setURL = URL(fileURLWithPath: setDirectory)
let masterURL = setURL.appendingPathComponent("icon_512x512@2x.png")

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

guard let source = CGImageSourceCreateWithURL(masterURL as CFURL, nil),
      let master = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fail("cannot read master icon at \(masterURL.path)")
}

/// Bounding box of pixels with a non-zero alpha channel.
func opaqueBounds(of image: CGImage) -> CGRect {
    let width = image.width
    let height = image.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    guard let context = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fail("cannot create bitmap context")
    }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    var minX = width, minY = height, maxX = -1, maxY = -1
    for y in 0..<height {
        for x in 0..<width where pixels[(y * width + x) * 4 + 3] != 0 {
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)
        }
    }
    guard maxX >= minX, maxY >= minY else { fail("master icon is fully transparent") }
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}

let bounds = opaqueBounds(of: master)
guard let content = master.cropping(to: bounds) else { fail("cannot crop master icon") }

let scale = body / max(bounds.width, bounds.height)
let drawSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
let drawRect = CGRect(
    x: (canvas - drawSize.width) / 2,
    y: (canvas - drawSize.height) / 2,
    width: drawSize.width,
    height: drawSize.height
)

guard let canvasContext = CGContext(
    data: nil,
    width: Int(canvas),
    height: Int(canvas),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fail("cannot create canvas context")
}
canvasContext.interpolationQuality = .high
canvasContext.draw(content, in: drawRect)
guard let padded = canvasContext.makeImage() else { fail("cannot render padded icon") }

func write(_ image: CGImage, side: Int, to url: URL) {
    guard let context = CGContext(
        data: nil,
        width: side,
        height: side,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fail("cannot create \(side)px context")
    }
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
    guard let scaled = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        fail("cannot write \(url.lastPathComponent)")
    }
    CGImageDestinationAddImage(destination, scaled, nil)
    guard CGImageDestinationFinalize(destination) else { fail("cannot finalize \(url.lastPathComponent)") }
}

let variants: [(name: String, side: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for variant in variants {
    write(padded, side: variant.side, to: setURL.appendingPathComponent(variant.name))
}

print("icon body \(Int(bounds.width))x\(Int(bounds.height)) -> \(Int(body))x\(Int(body)) inside \(Int(canvas))x\(Int(canvas))")
