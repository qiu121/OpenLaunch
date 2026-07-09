import Foundation

/// 计算两次应用扫描之间的用户可见列表变化。
public enum AppListChangeSummary {
    public static let defaultAnimatedAppLimit = 6

    /// 返回本次列表中相对上次新增的应用 id，顺序沿用当前列表顺序。
    public static func addedAppIDs(
        previousApps: [LaunchableApp],
        currentApps: [LaunchableApp],
        limit: Int = defaultAnimatedAppLimit
    ) -> [String] {
        guard limit > 0 else {
            return []
        }

        let previousIDs = Set(previousApps.map(\.stableKey))
        let addedIDs = currentApps
            .map(\.stableKey)
            .filter { !previousIDs.contains($0) }
        return Array(addedIDs.prefix(limit))
    }
}
