import Foundation

/// 管理自定义排序的稳定顺序，供 UI 拖拽和设置持久化共用。
public enum CustomAppOrder {
    /// 将已有顺序补齐到当前应用集合：保留旧顺序，追加新出现的应用。
    public static func normalizedOrder(currentAppIDs: [String], existingOrder: [String: Int]) -> [String] {
        guard !currentAppIDs.isEmpty else {
            return []
        }

        if existingOrder.isEmpty {
            return currentAppIDs
        }

        let currentIDSet = Set(currentAppIDs)
        let orderedExistingIDs = existingOrder
            .sorted { lhs, rhs in
                if lhs.value != rhs.value {
                    return lhs.value < rhs.value
                }

                return lhs.key < rhs.key
            }
            .map(\.key)
            .filter(currentIDSet.contains)
        let missingIDs = currentAppIDs.filter { existingOrder[$0] == nil }
        return orderedExistingIDs + missingIDs
    }

    /// 移动一个应用到目标应用附近；向前拖动放在目标前，向后拖动放在目标后。
    public static func movedOrder(
        currentAppIDs: [String],
        existingOrder: [String: Int],
        draggedAppID: String,
        targetAppID: String
    ) -> [String] {
        guard draggedAppID != targetAppID else {
            return normalizedOrder(currentAppIDs: currentAppIDs, existingOrder: existingOrder)
        }

        var orderedAppIDs = normalizedOrder(currentAppIDs: currentAppIDs, existingOrder: existingOrder)
        guard let sourceIndex = orderedAppIDs.firstIndex(of: draggedAppID),
              let originalTargetIndex = orderedAppIDs.firstIndex(of: targetAppID) else {
            return orderedAppIDs
        }

        orderedAppIDs.remove(at: sourceIndex)
        guard let targetIndexAfterRemoval = orderedAppIDs.firstIndex(of: targetAppID) else {
            return orderedAppIDs
        }

        let insertionIndex = sourceIndex < originalTargetIndex
            ? orderedAppIDs.index(after: targetIndexAfterRemoval)
            : targetIndexAfterRemoval
        orderedAppIDs.insert(draggedAppID, at: min(insertionIndex, orderedAppIDs.endIndex))
        return orderedAppIDs
    }

    /// 把顺序数组转换为可 JSON 持久化的序号字典。
    public static func dictionary(from appIDs: [String]) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: appIDs.enumerated().map { index, appID in
            (appID, index)
        })
    }
}
