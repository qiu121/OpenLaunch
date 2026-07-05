import AppKit
import QuartzCore

/// OpenLaunch 覆盖窗口的通用操作，避免依赖对无边框全屏窗口不稳定的应用隐藏。
@MainActor
enum OpenLaunchWindowActions {
    /// 关闭当前全屏覆盖层，但保持菜单栏应用继续运行。
    static func hide() {
        guard let launchWindow, launchWindow.isVisible else {
            return
        }

        launchWindow.ignoresMouseEvents = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            launchWindow.animator().alphaValue = 0
        } completionHandler: {
            Task { @MainActor in
                finishHiding(launchWindow)
            }
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard launchWindow.isVisible, launchWindow.alphaValue == 0 else {
                return
            }

            finishHiding(launchWindow)
        }
    }

    private static var launchWindow: NSWindow? {
        NSApp.windows.first { window in
            window.title == "OpenLaunch"
        }
    }

    private static func finishHiding(_ window: NSWindow) {
        window.orderOut(nil)
        window.alphaValue = 1
        window.ignoresMouseEvents = false
        var options = NSApp.presentationOptions
        options.remove(.autoHideMenuBar)
        NSApp.presentationOptions = options
    }
}
