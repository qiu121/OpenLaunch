#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO

enum BackgroundTestError: LocalizedError {
    case invalidArguments
    case unreadableImage(String)
    case unexpectedPixel(String)

    var errorDescription: String? {
        switch self {
        case .invalidArguments:
            return "用法：DMGBackgroundTests.swift <背景图片目录>"
        case let .unreadableImage(path):
            return "无法读取背景图片：\(path)"
        case let .unexpectedPixel(message):
            return message
        }
    }
}

struct Pixel {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let alpha: UInt8
}

func loadImage(at url: URL) throws -> CGImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw BackgroundTestError.unreadableImage(url.path)
    }
    return image
}

func pixel(in image: CGImage, x: Int, y: Int) throws -> Pixel {
    guard let sample = image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)) else {
        throw BackgroundTestError.unreadableImage("无法截取像素 (\(x), \(y))")
    }

    var bytes = [UInt8](repeating: 0, count: 4)
    guard let context = CGContext(
        data: &bytes,
        width: 1,
        height: 1,
        bitsPerComponent: 8,
        bytesPerRow: 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw BackgroundTestError.unreadableImage("无法创建像素采样上下文")
    }

    context.draw(sample, in: CGRect(x: 0, y: 0, width: 1, height: 1))
    return Pixel(red: bytes[0], green: bytes[1], blue: bytes[2], alpha: bytes[3])
}

func assertBackground(_ pixel: Pixel, label: String) throws {
    let expected = (red: 245, green: 247, blue: 250, alpha: 255)
    let tolerance = 3
    guard
        abs(Int(pixel.red) - expected.red) <= tolerance,
        abs(Int(pixel.green) - expected.green) <= tolerance,
        abs(Int(pixel.blue) - expected.blue) <= tolerance,
        pixel.alpha == expected.alpha
    else {
        throw BackgroundTestError.unexpectedPixel(
            "\(label) 背景色不符合 #F5F7FA，实际为 rgba(\(pixel.red), \(pixel.green), \(pixel.blue), \(pixel.alpha))"
        )
    }
}

func assertArrow(_ pixel: Pixel, label: String) throws {
    guard pixel.alpha == 255, pixel.red < 200, pixel.green < 200, pixel.blue < 200 else {
        throw BackgroundTestError.unexpectedPixel(
            "\(label) 未检测到居中箭头，实际为 rgba(\(pixel.red), \(pixel.green), \(pixel.blue), \(pixel.alpha))"
        )
    }
}

guard let directoryPath = CommandLine.arguments.dropFirst().first else {
    throw BackgroundTestError.invalidArguments
}

let directory = URL(fileURLWithPath: directoryPath, isDirectory: true)
let images = [
    (url: directory.appendingPathComponent("OpenLaunchDMGBackground.png"), scale: 1),
    (url: directory.appendingPathComponent("OpenLaunchDMGBackground@2x.png"), scale: 2),
]

for item in images {
    let image = try loadImage(at: item.url)
    let scale = item.scale
    try assertBackground(try pixel(in: image, x: 20 * scale, y: 20 * scale), label: "\(scale)x")

    let arrowPoints = [
        (x: 245, y: 180),
        (x: 280, y: 180),
        (x: 319, y: 180),
        (x: 311, y: 171),
        (x: 311, y: 189),
    ]
    for point in arrowPoints {
        try assertArrow(
            try pixel(in: image, x: point.x * scale, y: point.y * scale),
            label: "\(scale)x (\(point.x), \(point.y))"
        )
    }

    let surroundingBackgroundPoints = [
        (x: 235, y: 180),
        (x: 280, y: 165),
        (x: 330, y: 180),
    ]
    for point in surroundingBackgroundPoints {
        try assertBackground(
            try pixel(in: image, x: point.x * scale, y: point.y * scale),
            label: "\(scale)x (\(point.x), \(point.y))"
        )
    }
}

print("DMG background content tests passed")
