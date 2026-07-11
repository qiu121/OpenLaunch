#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO

enum AppIconTestError: LocalizedError {
    case invalidArguments
    case unreadableImage(String)
    case failedToCreateContext
    case highlightBoundaryDetected(Int)

    var errorDescription: String? {
        switch self {
        case .invalidArguments:
            return "用法：AppIconTests.swift <AppIcon PNG>"
        case let .unreadableImage(path):
            return "无法读取 AppIcon：\(path)"
        case .failedToCreateContext:
            return "无法创建 AppIcon 像素检测上下文"
        case let .highlightBoundaryDetected(delta):
            return "AppIcon 顶部仍存在横向高光分界，颜色突变量为 \(delta)"
        }
    }
}

guard let imagePath = CommandLine.arguments.dropFirst().first else {
    throw AppIconTestError.invalidArguments
}

let imageURL = URL(fileURLWithPath: imagePath)
guard
    let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
else {
    throw AppIconTestError.unreadableImage(imagePath)
}

let bytesPerRow = image.width * 4
var pixels = [UInt8](repeating: 0, count: bytesPerRow * image.height)
guard let context = CGContext(
    data: &pixels,
    width: image.width,
    height: image.height,
    bitsPerComponent: 8,
    bytesPerRow: bytesPerRow,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    throw AppIconTestError.failedToCreateContext
}

context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

func rgb(atX x: Int, y: Int) -> (red: Int, green: Int, blue: Int) {
    let offset = y * bytesPerRow + x * 4
    return (Int(pixels[offset]), Int(pixels[offset + 1]), Int(pixels[offset + 2]))
}

let sampleX = image.width / 2
let formerHighlightTop = Int((144.0 / 1024.0 * Double(image.height)).rounded())
let pixelBeforeBoundary = rgb(atX: sampleX, y: formerHighlightTop - 1)
let pixelAfterBoundary = rgb(atX: sampleX, y: formerHighlightTop)
let colorDelta = abs(pixelBeforeBoundary.red - pixelAfterBoundary.red)
    + abs(pixelBeforeBoundary.green - pixelAfterBoundary.green)
    + abs(pixelBeforeBoundary.blue - pixelAfterBoundary.blue)

guard colorDelta < 10 else {
    throw AppIconTestError.highlightBoundaryDetected(colorDelta)
}

print("App icon visual tests passed")
