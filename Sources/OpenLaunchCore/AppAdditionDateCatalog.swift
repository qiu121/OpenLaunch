import Foundation

/// 保存应用第一次被 OpenLaunch 确认的添加时间，避免应用更新后顺序发生漂移。
public struct AppAdditionDateCatalog: Codable, Equatable, Sendable {
    /// 按应用稳定键保存的添加时间。
    public private(set) var dates: [String: Date]

    /// 是否已经完成过首次扫描建档。
    public private(set) var isInitialized: Bool

    /// 尚未进行首次扫描的空目录。
    public static let uninitialized = AppAdditionDateCatalog(dates: [:], isInitialized: false)

    public init(dates: [String: Date], isInitialized: Bool) {
        self.dates = dates
        self.isInitialized = isInitialized
    }

    /// 为扫描结果补全稳定添加时间。首次建档采用系统元数据，后续新应用采用发现时间。
    public mutating func resolveAdditionDates(
        for apps: [LaunchableApp],
        detectedAt: Date
    ) -> [LaunchableApp] {
        let shouldSeedFromMetadata = !isInitialized
        var resolvedApps = apps

        for index in resolvedApps.indices {
            let stableKey = resolvedApps[index].stableKey

            if let savedDate = dates[stableKey] {
                resolvedApps[index].addedDate = savedDate
                continue
            }

            let resolvedDate: Date
            if shouldSeedFromMetadata, let metadataDate = resolvedApps[index].addedDate {
                resolvedDate = metadataDate
            } else {
                resolvedDate = detectedAt
            }

            dates[stableKey] = resolvedDate
            resolvedApps[index].addedDate = resolvedDate
        }

        isInitialized = true
        return resolvedApps
    }
}
