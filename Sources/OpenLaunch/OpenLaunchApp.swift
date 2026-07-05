import AppKit

/// OpenLaunch 的 AppKit 入口；窗口由 `AppDelegate` 显式创建，避免 SwiftUI Scene 自动恢复普通窗口。
@main
enum OpenLaunchApp {
    private static var appDelegate: AppDelegate?

    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        appDelegate = delegate
        application.delegate = delegate
        application.run()
    }
}
