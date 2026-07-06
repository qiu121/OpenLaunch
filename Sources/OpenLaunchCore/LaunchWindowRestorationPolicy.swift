import Foundation

/// 处理 SwiftUI 默认窗口恢复留下的状态，避免启动器退回普通窗口尺寸。
public enum LaunchWindowRestorationPolicy {
    public static let supportsSecureRestorableState = false
    public static let quitAlwaysKeepsWindows = false

    public static func staleWindowFrameKeys(in keys: [String]) -> [String] {
        keys.filter { key in
            key.hasPrefix("NSWindow Frame SwiftUI.")
                && key.contains("OpenLaunch.ContentView")
        }
    }
}
