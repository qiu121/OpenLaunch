#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// 生成 DMG/挂载卷图标：复用系统 Removable.icns 外壳，只重绘磁盘正面与 OpenLaunch 标记。
let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
let arguments = Array(CommandLine.arguments.dropFirst())
let outputRootURL = arguments.first.map { URL(fileURLWithPath: $0, isDirectory: true) }
    ?? rootURL.appendingPathComponent(".build/package-icons", isDirectory: true)
let iconsetURL = outputRootURL.appendingPathComponent("OpenLaunchDiskIcon.iconset", isDirectory: true)
let removableDiskURL = URL(fileURLWithPath: "/System/Library/Extensions/IOStorageFamily.kext/Contents/Resources/Removable.icns")

guard let removableDiskIcon = NSImage(contentsOf: removableDiskURL) else {
    throw IconGenerationError.failedToReadSystemDiskIcon(removableDiskURL.path)
}

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
    let image = drawVolumeIcon(pixelSize: pixels, diskIcon: removableDiskIcon)
    try writePNG(image, to: iconsetURL.appendingPathComponent(iconSize.name))
}

func drawVolumeIcon(pixelSize: Int, diskIcon: NSImage) -> NSImage {
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

    let canvasRect = CGRect(origin: .zero, size: size)
    diskIcon.draw(in: canvasRect, from: .zero, operation: .sourceOver, fraction: 1.0)

    let scale = CGFloat(pixelSize) / 1024
    drawTintedDiskFace(scale: scale, context: context)
    drawOpenLaunchMark(scale: scale, context: context)

    return image
}

func drawTintedDiskFace(scale: CGFloat, context: CGContext) {
    let faceRect = CGRect(x: 150 * scale, y: 188 * scale, width: 724 * scale, height: 742 * scale)
    let facePath = NSBezierPath(
        roundedRect: faceRect,
        xRadius: 72 * scale,
        yRadius: 72 * scale
    ).cgPath

    context.saveGState()
    context.addPath(facePath)
    context.clip()
    drawLinearGradient(
        in: faceRect,
        colors: [
            NSColor(calibratedRed: 0.90, green: 0.96, blue: 1.00, alpha: 1),
            NSColor(calibratedRed: 0.68, green: 0.86, blue: 1.00, alpha: 1),
            NSColor(calibratedRed: 0.40, green: 0.68, blue: 0.96, alpha: 1)
        ],
        start: CGPoint(x: faceRect.minX, y: faceRect.maxY),
        end: CGPoint(x: faceRect.maxX, y: faceRect.minY),
        context: context
    )
    context.restoreGState()
}

func drawOpenLaunchMark(scale: CGFloat, context: CGContext) {
    let cell = 132 * scale
    let gap = 34 * scale
    let total = cell * 3 + gap * 2
    let markCenterY: CGFloat = 559
    let origin = CGPoint(x: 512 * scale - total / 2, y: markCenterY * scale - total / 2)
    let cornerRadius = 34 * scale

    let colors: [[NSColor]] = [
        [
            NSColor(calibratedRed: 1.00, green: 0.42, blue: 0.40, alpha: 1),
            NSColor(calibratedRed: 1.00, green: 0.66, blue: 0.25, alpha: 1)
        ],
        [
            NSColor(calibratedRed: 0.28, green: 0.73, blue: 1.00, alpha: 1),
            NSColor(calibratedRed: 0.20, green: 0.48, blue: 1.00, alpha: 1)
        ],
        [
            NSColor(calibratedRed: 0.78, green: 0.50, blue: 1.00, alpha: 1),
            NSColor(calibratedRed: 0.93, green: 0.42, blue: 0.92, alpha: 1)
        ],
        [
            NSColor(calibratedRed: 0.24, green: 0.84, blue: 0.60, alpha: 1),
            NSColor(calibratedRed: 0.12, green: 0.65, blue: 0.70, alpha: 1)
        ],
        [
            NSColor(calibratedRed: 1.00, green: 0.78, blue: 0.24, alpha: 1),
            NSColor(calibratedRed: 1.00, green: 0.56, blue: 0.18, alpha: 1)
        ],
        [
            NSColor(calibratedRed: 0.22, green: 0.86, blue: 0.92, alpha: 1),
            NSColor(calibratedRed: 0.14, green: 0.58, blue: 0.92, alpha: 1)
        ],
        [
            NSColor(calibratedRed: 0.96, green: 0.42, blue: 0.88, alpha: 1),
            NSColor(calibratedRed: 0.68, green: 0.40, blue: 1.00, alpha: 1)
        ],
        [
            NSColor(calibratedRed: 0.48, green: 0.90, blue: 0.40, alpha: 1),
            NSColor(calibratedRed: 0.20, green: 0.74, blue: 0.44, alpha: 1)
        ],
        [
            NSColor(calibratedRed: 0.62, green: 0.80, blue: 1.00, alpha: 1),
            NSColor(calibratedRed: 0.46, green: 0.58, blue: 0.98, alpha: 1)
        ]
    ]

    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -5 * scale),
        blur: 10 * scale,
        color: NSColor.black.withAlphaComponent(0.16).cgColor
    )

    for row in 0..<3 {
        for column in 0..<3 {
            let index = row * 3 + column
            let rect = CGRect(
                x: origin.x + CGFloat(column) * (cell + gap),
                y: origin.y + CGFloat(2 - row) * (cell + gap),
                width: cell,
                height: cell
            )
            drawRoundedTile(in: rect, radius: cornerRadius, colors: colors[index], context: context)
        }
    }

    context.restoreGState()
}

func drawRoundedTile(in rect: CGRect, radius: CGFloat, colors: [NSColor], context: CGContext) {
    let tilePath = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).cgPath

    context.saveGState()
    context.addPath(tilePath)
    context.clip()
    drawLinearGradient(
        in: rect,
        colors: colors,
        start: CGPoint(x: rect.minX, y: rect.maxY),
        end: CGPoint(x: rect.maxX, y: rect.minY),
        context: context
    )
    context.restoreGState()

    context.addPath(tilePath)
    context.setStrokeColor(NSColor.white.withAlphaComponent(0.36).cgColor)
    context.setLineWidth(max(1, rect.width * 0.032))
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
    case failedToReadSystemDiskIcon(String)
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
