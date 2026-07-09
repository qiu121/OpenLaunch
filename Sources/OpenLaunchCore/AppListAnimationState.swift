import Foundation

/// 保存下一次启动台展示时需要播放入场动画的应用 id。
public struct AppListAnimationState: Equatable, Sendable {
    public private(set) var pendingAnimatedAppIDs: Set<String>

    public init(pendingAnimatedAppIDs: Set<String> = []) {
        self.pendingAnimatedAppIDs = pendingAnimatedAppIDs
    }

    /// 自动刷新后记录新增应用，下一次打开启动台时播放一次入场动画。
    public mutating func recordAutomaticRefresh(
        previousApps: [LaunchableApp],
        currentApps: [LaunchableApp]
    ) {
        guard !previousApps.isEmpty else {
            return
        }

        let addedAppIDs = Set(
            AppListChangeSummary.addedAppIDs(
                previousApps: previousApps,
                currentApps: currentApps
            )
        )
        pendingAnimatedAppIDs.formUnion(addedAppIDs)
    }

    /// 手动刷新不做新增提示，避免用户主动操作后出现额外动画。
    public mutating func recordManualRefresh(
        previousApps: [LaunchableApp],
        currentApps: [LaunchableApp]
    ) {
        pendingAnimatedAppIDs = []
    }

    /// 取出并清空待播放动画的应用 id，保证每次变更只提示一次。
    public mutating func consumePendingAnimatedAppIDs() -> Set<String> {
        let appIDs = pendingAnimatedAppIDs
        pendingAnimatedAppIDs = []
        return appIDs
    }
}
