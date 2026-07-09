import Foundation

/// 应用目录发生变化后，启动台应该采取的刷新动作。
public enum ApplicationRefreshAction: Equatable {
    /// 立即重新扫描应用列表。
    case rescanImmediately
    /// 不需要执行任何动作。
    case noAction
}

/// 应用自动刷新策略，保证安装或移除应用后后台刷新列表。
public struct ApplicationRefreshPolicy {
    public init() {}

    /// 处理应用目录变化；安装或移除应用后应立即后台刷新，保证下次打开无需手动扫描。
    public mutating func handleApplicationDirectoryChange(isLauncherVisible: Bool) -> ApplicationRefreshAction {
        return .rescanImmediately
    }

    /// 处理启动台即将显示事件；目录变化已在后台刷新，这里无需额外扫描。
    public mutating func handleLauncherWillShow() -> ApplicationRefreshAction {
        .noAction
    }

    /// 手动重新扫描始终立即执行。
    public mutating func handleManualRescan() -> ApplicationRefreshAction {
        return .rescanImmediately
    }
}
