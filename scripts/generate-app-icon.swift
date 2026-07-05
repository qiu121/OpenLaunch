#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// 生成 OpenLaunch 的 Dock 图标资源；菜单栏状态项图标不依赖这里。
let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
let resourcesURL = rootURL.appendingPathComponent("Resources", isDirectory: true)
let iconsetURL = resourcesURL.appendingPathComponent("OpenLaunchAppIcon.iconset", isDirectory: true)

try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let iconSizes: [(name: String, points: CGFloat, scale: CGFloat)] = [
    ("icon_16x16.png", 16, 1),
    ("icon_16x16@2x.png", 16, 2),
    ("icon_32x32.png", 32, 1),
    ("icon_32x32@2x.png", 32, 2),
    ("icon_128x128.png", 128, 1),
    ("icon_128x128@2x.png", 128, 2),
    ("icon_256x256.png", 256, 1),
    ("icon_256x256@2x.png", 256, 2),
    ("icon_512x512.png", 512, 1),
    ("icon_512x512@2x.png", 512, 2)
]

for iconSize in iconSizes {
    let pixels = Int(iconSize.points * iconSize.scale)
    let image = drawIcon(pixelSize: pixels)
    try writePNG(image, to: iconsetURL.appendingPathComponent(iconSize.name))
}

func drawIcon(pixelSize: Int) -> NSImage {
    let size = NSSize(width: pixelSize, height: pixelSize)
    let image = NSImage(size: size)

    image.lockFocus()
    defer { image.unlockFocus() }

    guard let context = NSGraphicsContext.current?.cgContext else {
        return image
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.clear(CGRect(origin: .zero, size: size))

    let scale = CGFloat(pixelSize) / 1024
    func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
        CGRect(x: x * scale, y: y * scale, width: width * scale, height: height * scale)
    }

    let bodyRect = rect(74, 72, 876, 876)
    let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: 210 * scale, yRadius: 210 * scale)
    let bodyCGPath = bodyPath.cgPath

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -26 * scale), blur: 36 * scale, color: NSColor.black.withAlphaComponent(0.28).cgColor)
    context.addPath(bodyCGPath)
    context.clip()
    drawLinearGradient(
        in: bodyRect,
        colors: [
            NSColor(calibratedRed: 0.90, green: 0.97, blue: 1.00, alpha: 1.0),
            NSColor(calibratedRed: 0.37, green: 0.71, blue: 0.98, alpha: 1.0),
            NSColor(calibratedRed: 0.16, green: 0.45, blue: 0.88, alpha: 1.0)
        ],
        start: CGPoint(x: bodyRect.minX, y: bodyRect.maxY),
        end: CGPoint(x: bodyRect.maxX, y: bodyRect.minY),
        context: context
    )
    context.restoreGState()

    context.saveGState()
    context.addPath(bodyCGPath)
    context.clip()
    drawLinearGradient(
        in: rect(92, 590, 840, 300),
        colors: [
            NSColor.white.withAlphaComponent(0.45),
            NSColor.white.withAlphaComponent(0.04)
        ],
        start: CGPoint(x: 0, y: 880 * scale),
        end: CGPoint(x: 0, y: 570 * scale),
        context: context
    )
    context.restoreGState()

    context.addPath(bodyCGPath)
    context.setStrokeColor(NSColor.white.withAlphaComponent(0.52).cgColor)
    context.setLineWidth(3 * scale)
    context.strokePath()

    let tileColors: [(NSColor, NSColor)] = [
        (NSColor(calibratedRed: 0.98, green: 0.35, blue: 0.42, alpha: 1), NSColor(calibratedRed: 1.00, green: 0.67, blue: 0.35, alpha: 1)),
        (NSColor(calibratedRed: 0.34, green: 0.78, blue: 1.00, alpha: 1), NSColor(calibratedRed: 0.15, green: 0.48, blue: 0.98, alpha: 1)),
        (NSColor(calibratedRed: 0.55, green: 0.50, blue: 1.00, alpha: 1), NSColor(calibratedRed: 0.83, green: 0.40, blue: 1.00, alpha: 1)),
        (NSColor(calibratedRed: 0.36, green: 0.86, blue: 0.54, alpha: 1), NSColor(calibratedRed: 0.12, green: 0.63, blue: 0.92, alpha: 1)),
        (NSColor(calibratedRed: 1.00, green: 0.83, blue: 0.28, alpha: 1), NSColor(calibratedRed: 1.00, green: 0.52, blue: 0.19, alpha: 1)),
        (NSColor(calibratedRed: 0.30, green: 0.95, blue: 0.82, alpha: 1), NSColor(calibratedRed: 0.11, green: 0.59, blue: 0.92, alpha: 1)),
        (NSColor(calibratedRed: 0.96, green: 0.47, blue: 0.82, alpha: 1), NSColor(calibratedRed: 0.58, green: 0.35, blue: 0.98, alpha: 1)),
        (NSColor(calibratedRed: 0.65, green: 0.96, blue: 0.39, alpha: 1), NSColor(calibratedRed: 0.17, green: 0.76, blue: 0.40, alpha: 1)),
        (NSColor(calibratedRed: 0.93, green: 0.96, blue: 1.00, alpha: 1), NSColor(calibratedRed: 0.48, green: 0.62, blue: 0.98, alpha: 1))
    ]

    let tileSize: CGFloat = 164
    let tileGap: CGFloat = 54
    let gridSize = tileSize * 3 + tileGap * 2
    let originX = (1024 - gridSize) / 2
    let originY = (1024 - gridSize) / 2 - 10

    for row in 0..<3 {
        for column in 0..<3 {
            let index = row * 3 + column
            let tileRect = rect(
                originX + CGFloat(column) * (tileSize + tileGap),
                originY + CGFloat(2 - row) * (tileSize + tileGap),
                tileSize,
                tileSize
            )

            drawTile(in: tileRect, colors: tileColors[index], scale: scale, context: context)
        }
    }

    return image
}

func drawTile(in tileRect: CGRect, colors: (NSColor, NSColor), scale: CGFloat, context: CGContext) {
    let path = NSBezierPath(roundedRect: tileRect, xRadius: 38 * scale, yRadius: 38 * scale).cgPath

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10 * scale), blur: 18 * scale, color: NSColor.black.withAlphaComponent(0.24).cgColor)
    context.addPath(path)
    context.clip()
    drawLinearGradient(
        in: tileRect,
        colors: [colors.0, colors.1],
        start: CGPoint(x: tileRect.minX, y: tileRect.maxY),
        end: CGPoint(x: tileRect.maxX, y: tileRect.minY),
        context: context
    )
    context.restoreGState()

    context.addPath(path)
    context.setStrokeColor(NSColor.white.withAlphaComponent(0.54).cgColor)
    context.setLineWidth(2 * scale)
    context.strokePath()
}

func drawLinearGradient(in rect: CGRect, colors: [NSColor], start: CGPoint, end: CGPoint, context: CGContext) {
    let cgColors = colors.map { $0.cgColor } as CFArray
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let gradient = CGGradient(colorsSpace: colorSpace, colors: cgColors, locations: nil) else {
        return
    }

    context.drawLinearGradient(gradient, start: start, end: end, options: [])
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw IconGenerationError.failedToWritePNG(url.path)
    }

    CGImageDestinationAddImage(destination, cgImage, nil)
    if !CGImageDestinationFinalize(destination) {
        throw IconGenerationError.failedToWritePNG(url.path)
    }
}

enum IconGenerationError: Error {
    case failedToWritePNG(String)
}

extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [NSPoint](repeating: .zero, count: 3)

        for index in 0..<elementCount {
            switch element(at: index, associatedPoints: &points) {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }

        return path
    }
}
