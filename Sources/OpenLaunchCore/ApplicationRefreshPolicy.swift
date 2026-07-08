import Foundation

/// 应用目录发生变化后，启动台应该采取的刷新动作。
public enum ApplicationRefreshAction: Equatable {
    /// 立即重新扫描应用列表。
    case rescanImmediately
    /// 记录待刷新状态，等待下一次显示启动台时扫描。
    case markNeedsRefresh
    /// 不需要执行任何动作。
    case noAction
}

/// 应用自动刷新策略，避免隐藏状态下频繁扫描，也避免显示时错过新增应用。
public struct ApplicationRefreshPolicy {
    public private(set) var needsRefresh: Bool

    public init(needsRefresh: Bool = false) {
        self.needsRefresh = needsRefresh
    }

    /// 处理应用目录变化；启动台可见时立即刷新，隐藏时延迟到下次打开。
    public mutating func handleApplicationDirectoryChange(isLauncherVisible: Bool) -> ApplicationRefreshAction {
        if isLauncherVisible {
            needsRefresh = false
            return .rescanImmediately
        }

        needsRefresh = true
        return .markNeedsRefresh
    }

    /// 处理启动台即将显示事件；如果之前检测到目录变化，则消费待刷新标记。
    public mutating func handleLauncherWillShow() -> ApplicationRefreshAction {
        guard needsRefresh else {
            return .noAction
        }

        needsRefresh = false
        return .rescanImmediately
    }

    /// 手动重新扫描始终立即执行，并清除自动刷新待处理状态。
    public mutating func handleManualRescan() -> ApplicationRefreshAction {
        needsRefresh = false
        return .rescanImmediately
    }
}
