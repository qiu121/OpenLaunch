import Foundation

/// 负责按照用户设置对应用列表进行稳定排序。
public enum AppSorter {
    /// 返回过滤隐藏项后的排序结果。
    public static func sorted(_ apps: [LaunchableApp], using settings: OpenLaunchSettings) -> [LaunchableApp] {
        let visibleApps = apps.filter { !$0.isHidden }

        switch settings.sortMode {
        case .addedDate:
            return visibleApps.sorted(by: compareByAddedDate)
        case .name:
            return visibleApps.sorted(by: compareByName)
        case .lastOpened:
            return visibleApps.sorted(by: compareByLastOpened)
        case .custom:
            return visibleApps.sorted { lhs, rhs in
                let lhsOrder = settings.customOrder[lhs.stableKey]
                let rhsOrder = settings.customOrder[rhs.stableKey]

                switch (lhsOrder, rhsOrder) {
                case let (left?, right?) where left != right:
                    return left < right
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                default:
                    return compareByName(lhs, rhs)
                }
            }
        }
    }

    private static func compareByAddedDate(_ lhs: LaunchableApp, _ rhs: LaunchableApp) -> Bool {
        switch (lhs.addedDate, rhs.addedDate) {
        case let (left?, right?) where left != right:
            return left < right
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return compareByName(lhs, rhs)
        }
    }

    private static func compareByLastOpened(_ lhs: LaunchableApp, _ rhs: LaunchableApp) -> Bool {
        switch (lhs.lastOpenedDate, rhs.lastOpenedDate) {
        case let (left?, right?) where left != right:
            return left < right
        case (_?, nil):
            return false
        case (nil, _?):
            return true
        default:
            return compareByName(lhs, rhs)
        }
    }

    private static func compareByName(_ lhs: LaunchableApp, _ rhs: LaunchableApp) -> Bool {
        let nameComparison = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
        if nameComparison != .orderedSame {
            return nameComparison == .orderedAscending
        }
        return lhs.path.localizedCaseInsensitiveCompare(rhs.path) == .orderedAscending
    }
}
