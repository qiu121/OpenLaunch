import AppKit
import OpenLaunchCore
import QuartzCore

/// 管理 OpenLaunch 的全屏覆盖窗口。
@MainActor
final class LaunchWindowController {
    private enum DockOrientation: String {
        case bottom
        case left
        case right
    }

    /// 准备窗口样式：无标题栏、透明背景、跨 Space 辅助显示。
    func prepare(_ window: NSWindow) {
        window.title = "OpenLaunch"
        window.styleMask = [.borderless, .fullSizeContentView]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.restorationClass = nil
        window.acceptsMouseMovedEvents = true
        window.level = launcherWindowLevel
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        window.animationBehavior = .utilityWindow
    }

    /// 在鼠标所在屏幕上全屏显示窗口。
    func show(_ window: NSWindow) {
        prepare(window)

        let screen = targetScreen(for: window)
        if let screen {
            window.setFrame(fullscreenFrameRespectingDock(on: screen), display: true)
        }

        let wasVisible = window.isVisible
        if !wasVisible, LauncherChromePolicy.usesWindowAlphaFadeOnPresentation {
            window.alphaValue = 0
        } else {
            window.alphaValue = 1
        }

        window.ignoresMouseEvents = false
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        if LauncherChromePolicy.ordersWindowFrontRegardless {
            window.orderFrontRegardless()
        }
        hideMenuBarIfPossible()

        if !wasVisible, LauncherChromePolicy.usesWindowAlphaFadeOnPresentation {
            fadeIn(window)
        } else {
            window.alphaValue = 1
        }
    }

    /// 在显示和隐藏之间切换。
    func toggle(_ window: NSWindow) {
        if window.isVisible {
            hide(window)
        } else {
            show(window)
        }
    }

    /// 隐藏覆盖窗口但保持状态栏应用运行。
    func hide(_ window: NSWindow) {
        guard window.isVisible else {
            return
        }

        let restoredLevel = launcherWindowLevel
        window.ignoresMouseEvents = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 0
        } completionHandler: { [weak self, weak window] in
            Task { @MainActor in
                guard let self, let window else {
                    return
                }

                self.finishHiding(window, restoredLevel: restoredLevel)
            }
        }

        Task { @MainActor [weak self, weak window] in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard let self, let window, window.isVisible, window.alphaValue == 0 else {
                return
            }

            self.finishHiding(window, restoredLevel: restoredLevel)
        }
    }

    private func screenContainingMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { screen in
            NSMouseInRect(mouseLocation, screen.frame, false)
        }
    }

    /// 当前显示目标屏幕，用于窗口定位和背景截图。
    func targetScreen(for window: NSWindow?) -> NSScreen? {
        screenContainingMouse() ?? window?.screen ?? NSScreen.main
    }

    /// 计算覆盖窗口尺寸：自动隐藏 Dock 场景全屏覆盖；常显 Dock 场景避开 Dock 区域。
    private func fullscreenFrameRespectingDock(on screen: NSScreen) -> NSRect {
        var frame = screen.frame
        let orientation = dockOrientation()

        if isDockAutoHidden() {
            return frame
        }

        let visibleFrame = screen.visibleFrame
        switch orientation {
        case .bottom:
            let dockHeight = max(visibleFrame.minY - screen.frame.minY, 0)
            frame.origin.y += dockHeight
            frame.size.height -= dockHeight
        case .left:
            let dockWidth = max(visibleFrame.minX - screen.frame.minX, 0)
            frame.origin.x += dockWidth
            frame.size.width -= dockWidth
        case .right:
            let dockWidth = max(screen.frame.maxX - visibleFrame.maxX, 0)
            frame.size.width -= dockWidth
        }

        return frame
    }

    private func dockOrientation() -> DockOrientation {
        let defaults = UserDefaults(suiteName: "com.apple.dock")
        let rawValue = defaults?.string(forKey: "orientation") ?? DockOrientation.bottom.rawValue
        return DockOrientation(rawValue: rawValue) ?? .bottom
    }

    private func isDockAutoHidden() -> Bool {
        UserDefaults(suiteName: "com.apple.dock")?.bool(forKey: "autohide") ?? false
    }

    private var launcherWindowLevel: NSWindow.Level {
        NSWindow.Level(rawValue: Int(LauncherChromePolicy.contentWindowLevelRawValue))
    }

    func hideMenuBarIfPossible() {
        guard !LauncherChromePolicy.requiresActiveApplicationForMenuBarHiding || NSApp.isActive else {
            return
        }

        var options = NSApp.presentationOptions
        options.remove(.autoHideMenuBar)
        options.remove(.hideMenuBar)
        options.remove(.autoHideDock)
        options.remove(.hideDock)
        if LauncherChromePolicy.usesAutoHideSystemBars {
            options.insert(.autoHideMenuBar)
            options.insert(.autoHideDock)
        }
        NSApp.presentationOptions = options
    }

    private func restoreMenuBarAfterLauncherHides() {
        var options = NSApp.presentationOptions
        options.remove(.autoHideMenuBar)
        options.remove(.hideMenuBar)
        options.remove(.autoHideDock)
        options.remove(.hideDock)
        NSApp.presentationOptions = options
        if LauncherChromePolicy.returnsToAccessoryAfterHiding {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private func finishHiding(_ window: NSWindow, restoredLevel: NSWindow.Level) {
        window.orderOut(nil)
        window.alphaValue = 1
        window.level = restoredLevel
        window.ignoresMouseEvents = false
        restoreMenuBarAfterLauncherHides()
        NotificationCenter.default.post(name: .openLaunchDidHide, object: nil)
    }

    private func fadeIn(_ window: NSWindow) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        } completionHandler: { [weak window] in
            Task { @MainActor in
                window?.alphaValue = 1
            }
        }

        Task { @MainActor [weak window] in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard let window, window.isVisible else {
                return
            }

            window.alphaValue = 1
        }
    }

    /// 读取目标屏幕的系统桌面背景，供 SwiftUI 进行模糊背景渲染。
    func captureBackgroundImage(for window: NSWindow?) -> NSImage? {
        guard let screen = targetScreen(for: window),
              let imageURL = NSWorkspace.shared.desktopImageURL(for: screen) else {
            return nil
        }

        return NSImage(contentsOf: imageURL)
    }
}
