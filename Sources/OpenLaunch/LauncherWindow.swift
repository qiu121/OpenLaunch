import AppKit

/// OpenLaunch 的主覆盖窗口。无边框窗口默认不一定能成为 key window，会影响搜索输入和 Escape 退出。
final class LauncherWindow: NSWindow {
    var shouldConsumeMouseDown: ((NSEvent, NSWindow) -> Bool)?
    var didDispatchMouseUp: ((NSEvent, NSWindow) -> Void)?

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown,
           shouldConsumeMouseDown?(event, self) == true {
            return
        }

        super.sendEvent(event)

        if event.type == .leftMouseUp {
            didDispatchMouseUp?(event, self)
        }
    }
}
