# DMG Install Window Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 OpenLaunch DMG 安装窗口增加清晰、克制且支持 Retina 的拖拽方向箭头。

**Architecture:** 使用独立 Swift/AppKit 脚本生成 `1x` 与 `2x` PNG 背景，输出到 `.build/package-assets/`。`package-dmg.sh` 在 dmgbuild 前生成背景，dmgbuild settings 引用基础 PNG 并自动合并同名 `@2x` 资源。

**Tech Stack:** Swift 6、AppKit、CoreGraphics、ImageIO、dmgbuild 1.6.7、Bash。

## Global Constraints

- Finder 窗口维持 `560 × 360`。
- 背景颜色维持 `#F5F7FA`。
- `OpenLaunch.app` 与 `Applications` 中心维持 `(150, 180)` 和 `(410, 180)`。
- 箭头中心为 `(280, 180)`，宽约 `82pt`、高约 `24pt`、线宽约 `5pt`。
- 不显示标题、安装说明、装饰纹样、阴影、渐变或发光效果。
- 生成的 PNG 位于 `.build/`，不得提交。
- 不修改 OpenLaunch 应用运行时逻辑。

---

### Task 1: 生成并接入 HiDPI DMG 背景

**Files:**
- Create: `scripts/generate-dmg-background.swift`
- Modify: `scripts/package-dmg.sh`
- Modify: `scripts/dmgbuild-openlaunch.py`
- Test: `Tests/PackageVersionTests.sh`

**Interfaces:**
- Consumes: 命令行第一个参数为输出目录；缺省为 `.build/package-assets/`。
- Produces: `OpenLaunchDMGBackground.png`（`560 × 360`）和 `OpenLaunchDMGBackground@2x.png`（`1120 × 720`）。

- [ ] **Step 1: 为背景生成和打包接入编写失败约束测试**

在 `Tests/PackageVersionTests.sh` 中增加背景脚本路径，并断言：

```bash
DMG_BACKGROUND_SWIFT="$ROOT_DIR/scripts/generate-dmg-background.swift"

assert_file_exists "$DMG_BACKGROUND_SWIFT" "DMG packaging must keep a Swift background generator"
assert_contains 'generate-dmg-background.swift' "$DMG_SCRIPT" "DMG packaging must generate its Finder background"
assert_contains 'background = ".build/package-assets/OpenLaunchDMGBackground.png"' "$DMGBUILD_SETTINGS" "DMG layout must use the generated background image"
assert_not_contains 'background = "#f5f7fa"' "$DMGBUILD_SETTINGS" "DMG layout must not fall back to a plain color without the drag arrow"
```

在现有图标临时目录测试之后增加实际图片生成与尺寸验证：

```bash
assert_image_dimensions() {
    local file="$1"
    local expected_width="$2"
    local expected_height="$3"
    local message="$4"
    local actual_width
    local actual_height

    actual_width="$(sips -g pixelWidth "$file" | awk '/pixelWidth/ { print $2 }')"
    actual_height="$(sips -g pixelHeight "$file" | awk '/pixelHeight/ { print $2 }')"

    if [[ "$actual_width" != "$expected_width" || "$actual_height" != "$expected_height" ]]; then
        echo "FAIL: $message" >&2
        echo "  expected: ${expected_width}x${expected_height}" >&2
        echo "  actual:   ${actual_width}x${actual_height}" >&2
        exit 1
    fi
}

BACKGROUND_TMP_DIR="$TMP_DIR/dmg-background"
swift "$DMG_BACKGROUND_SWIFT" "$BACKGROUND_TMP_DIR"
assert_file_exists "$BACKGROUND_TMP_DIR/OpenLaunchDMGBackground.png" "DMG background generator must create the 1x image"
assert_file_exists "$BACKGROUND_TMP_DIR/OpenLaunchDMGBackground@2x.png" "DMG background generator must create the 2x image"
assert_image_dimensions "$BACKGROUND_TMP_DIR/OpenLaunchDMGBackground.png" 560 360 "DMG 1x background must match the Finder window"
assert_image_dimensions "$BACKGROUND_TMP_DIR/OpenLaunchDMGBackground@2x.png" 1120 720 "DMG 2x background must match the Retina Finder window"
```

- [ ] **Step 2: 运行测试确认因缺少背景生成器而失败**

Run: `bash Tests/PackageVersionTests.sh`

Expected: FAIL，提示 `scripts/generate-dmg-background.swift` 不存在。

- [ ] **Step 3: 实现最小背景生成器**

创建 `scripts/generate-dmg-background.swift`：

```swift
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

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
let outputDirectory = CommandLine.arguments.dropFirst().first
    .map { URL(fileURLWithPath: $0, isDirectory: true) }
    ?? rootURL.appendingPathComponent(".build/package-assets", isDirectory: true)

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for scale in [1, 2] {
    let image = try drawBackground(scale: scale)
    let suffix = scale == 1 ? "" : "@2x"
    let outputURL = outputDirectory.appendingPathComponent("OpenLaunchDMGBackground\(suffix).png")
    try writePNG(image, to: outputURL)
}

func drawBackground(scale: Int) throws -> CGImage {
    let factor = CGFloat(scale)
    let width = 560 * scale
    let height = 360 * scale
    let colorSpace = CGColorSpaceCreateDeviceRGB()

    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw BackgroundGenerationError.failedToCreateContext(scale)
    }

    context.setFillColor(CGColor(red: 245.0 / 255.0, green: 247.0 / 255.0, blue: 250.0 / 255.0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

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
```

- [ ] **Step 4: 将背景生成接入 DMG 打包**

在 `scripts/package-dmg.sh` 中增加：

```bash
DMG_ASSET_DIR="$ROOT_DIR/.build/package-assets"
DMG_BACKGROUND_SCRIPT="$ROOT_DIR/scripts/generate-dmg-background.swift"
```

在构建 App 和卷图标之后调用：

```bash
swift "$DMG_BACKGROUND_SCRIPT" "$DMG_ASSET_DIR"
```

在 `scripts/dmgbuild-openlaunch.py` 中替换背景配置：

```python
background = ".build/package-assets/OpenLaunchDMGBackground.png"
```

- [ ] **Step 5: 运行打包约束测试确认转绿**

Run: `bash Tests/PackageVersionTests.sh`

Expected: `Package version tests passed`。

- [ ] **Step 6: 运行完整回归检查**

Run:

```bash
swift test --scratch-path /tmp/openlaunch-dmg-background-tests
git diff --check
```

Expected: 78 项 Swift 测试通过，`git diff --check` 无输出。

- [ ] **Step 7: 保留代码提交边界**

最终与文档一并形成单次完整提交：

```bash
git add Resources/OpenLaunchAppIcon.icns Resources/OpenLaunchAppIcon.iconset Tests/AppIconTests.swift Tests/DMGBackgroundTests.swift Tests/PackageVersionTests.sh docs/Development.md docs/Release.md docs/superpowers/plans/2026-07-11-dmg-install-window.md docs/superpowers/specs/2026-07-11-dmg-install-window-design.md scripts/dmgbuild-openlaunch.py scripts/generate-app-icon.swift scripts/generate-dmg-background.swift scripts/package-dmg.sh
git commit -m "feat(package): 优化 DMG 拖拽安装引导"
```

本轮仅在用户明确要求提交时执行。

---

### Task 2: 文档与实际 DMG 验收

**Files:**
- Modify: `docs/Development.md`
- Modify: `docs/Release.md`
- Test: `Tests/PackageVersionTests.sh`

**Interfaces:**
- Consumes: Task 1 生成的两张 PNG 与更新后的 dmgbuild settings。
- Produces: 可供开发者复现的背景生成说明和通过视觉验收的 DMG。

- [ ] **Step 1: 更新开发与发布说明**

在 `docs/Development.md` 的 DMG 打包说明中补充：

```text
DMG 安装背景由 scripts/generate-dmg-background.swift 在打包时生成，1x/2x PNG 写入 .build/package-assets/，不提交生成图片。
```

在 `docs/Release.md` 的 DMG 打包说明中补充：

```text
安装窗口使用纯色 HiDPI 背景和居中直箭头提示拖拽方向；dmgbuild 自动组合基础图片与 @2x 图片。
```

- [ ] **Step 2: 构建 DMG**

Run: `bash scripts/package-dmg.sh`

Expected: 输出 `.build/dist/OpenLaunch-<package-version>.dmg`，命令退出码为 0。

- [ ] **Step 3: 挂载并检查 Finder 安装窗口**

Run:

```bash
open .build/dist/OpenLaunch-<package-version>.dmg
```

检查：箭头居中、指向 Applications、不遮挡图标或标签、无多余标题和说明。

- [ ] **Step 4: 完成最终验证**

Run:

```bash
bash Tests/PackageVersionTests.sh
swift test --scratch-path /tmp/openlaunch-dmg-final-tests
git diff --check
git status --short
```

Expected: 所有测试通过；仅列出本次实现和文档文件，不出现 `.build/` 产物。

- [ ] **Step 5: 合并代码与文档提交边界**

代码、测试与文档使用 Task 1 定义的同一次完整提交，不再拆分文档提交。

```bash
git status --short
```

本轮仅在用户明确要求提交时执行。
