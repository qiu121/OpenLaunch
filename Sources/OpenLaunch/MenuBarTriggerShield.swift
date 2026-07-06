import AppKit
import OpenLaunchCore

/// 覆盖顶部系统菜单栏触发区的透明窗口，避免鼠标贴顶时菜单栏浮出。
@MainActor
final class MenuBarTriggerShield {
    private var window: MenuBarTriggerShieldWindow?

    func show(on screen: NSScreen?) {
        guard LauncherChromePolicy.usesTransparentMenuBarTriggerShield,
              let screen else {
            return
        }

        let shieldWindow = window ?? MenuBarTriggerShieldWindow()
        window = shieldWindow
        shieldWindow.configure()
        shieldWindow.setFrame(frame(on: screen), display: true)
        shieldWindow.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func frame(on screen: NSScreen) -> NSRect {
        let height = LauncherChromePolicy.menuBarTriggerShieldHeight
        return NSRect(
            x: screen.frame.minX,
            y: screen.frame.maxY - height,
            width: screen.frame.width,
            height: height
        )
    }
}

/// 透明但接收鼠标事件的顶层窗口；不参与 key/main window，避免抢走搜索输入焦点。
private final class MenuBarTriggerShieldWindow: NSWindow {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func configure() {
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        isReleasedWhenClosed = false
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        contentView = NSView(frame: .zero)
    }
}
