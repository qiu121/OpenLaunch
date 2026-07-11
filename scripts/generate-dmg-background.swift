#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum BackgroundGenerationError: LocalizedError {
    case failedToCreateContext(Int)
    case failedToCreateImage(Int)
    case failedToCreateDestination(String)
    case failedToWritePNG(String)

    var errorDescription: String? {
        switch self {
        case let .failedToCreateContext(scale):
            return "无法创建 \(scale)x DMG 背景图形上下文"
        case let .failedToCreateImage(scale):
            return "无法生成 \(scale)x DMG 背景图片"
        case let .failedToCreateDestination(path):
            return "无法创建 PNG 输出：\(path)"
        case let .failedToWritePNG(path):
            return "无法写入 PNG：\(path)"
        }
    }
}

func drawBackground(scale: Int) throws -> CGImage {
    let factor = CGFloat(scale)
    let width = 560 * scale
    let height = 360 * scale

    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw BackgroundGenerationError.failedToCreateContext(scale)
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.setFillColor(
        CGColor(
            red: 245.0 / 255.0,
            green: 247.0 / 255.0,
            blue: 250.0 / 255.0,
            alpha: 1
        )
    )
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    // 箭头只提示拖拽方向，保持低于应用图标的视觉层级。
    context.setStrokeColor(CGColor(red: 0.38, green: 0.40, blue: 0.43, alpha: 0.82))
    context.setLineWidth(5 * factor)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.beginPath()
    context.move(to: CGPoint(x: 239 * factor, y: 180 * factor))
    context.addLine(to: CGPoint(x: 321 * factor, y: 180 * factor))
    context.move(to: CGPoint(x: 307 * factor, y: 168 * factor))
    context.addLine(to: CGPoint(x: 321 * factor, y: 180 * factor))
    context.addLine(to: CGPoint(x: 307 * factor, y: 192 * factor))
    context.strokePath()

    guard let image = context.makeImage() else {
        throw BackgroundGenerationError.failedToCreateImage(scale)
    }
    return image
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw BackgroundGenerationError.failedToCreateDestination(url.path)
    }

    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw BackgroundGenerationError.failedToWritePNG(url.path)
    }
}

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
let outputDirectory = CommandLine.arguments.dropFirst().first
    .map { URL(fileURLWithPath: $0, isDirectory: true) }
    ?? rootURL.appendingPathComponent(".build/package-assets", isDirectory: true)

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let staleScaleVariants = try FileManager.default.contentsOfDirectory(
    at: outputDirectory,
    includingPropertiesForKeys: nil
).filter {
    let name = $0.lastPathComponent
    return name.hasPrefix("OpenLaunchDMGBackground@") && name.hasSuffix("x.png")
}

for staleVariant in staleScaleVariants {
    try FileManager.default.removeItem(at: staleVariant)
}

for scale in [1, 2] {
    let image = try drawBackground(scale: scale)
    let suffix = scale == 1 ? "" : "@2x"
    let outputURL = outputDirectory.appendingPathComponent("OpenLaunchDMGBackground\(suffix).png")
    try writePNG(image, to: outputURL)
    print("Generated \(outputURL.path)")
}
