import Foundation

/// 可被 OpenLaunch 展示和启动的 macOS 应用记录。
public struct LaunchableApp: Identifiable, Codable, Equatable, Hashable, Sendable {
    /// 应用的 bundle identifier；读取失败时允许为空。
    public let bundleIdentifier: String?

    /// `.app` bundle 在文件系统中的绝对路径。
    public let path: String

    /// 展示给用户看的应用名称。
    public var displayName: String

    /// Launch Services 分类，例如生产力、开发者工具等。
    public var category: String?

    /// 应用被系统记录的添加时间；无法读取时使用创建时间或修改时间降级。
    public var addedDate: Date?

    /// `.app` bundle 的文件修改时间。
    public var modifiedDate: Date?

    /// 用户最近一次通过 OpenLaunch 打开该应用的时间。
    public var lastOpenedDate: Date?

    /// 是否在启动器中隐藏该应用。
    public var isHidden: Bool

    public var id: String {
        stableKey
    }

    /// 用于排序、去重和持久化布局的稳定键。
    public var stableKey: String {
        if let bundleIdentifier, !bundleIdentifier.isEmpty {
            return bundleIdentifier
        }
        return path
    }

    public init(
        bundleIdentifier: String?,
        path: String,
        displayName: String,
        category: String? = nil,
        addedDate: Date?,
        modifiedDate: Date? = nil,
        lastOpenedDate: Date? = nil,
        isHidden: Bool = false
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.path = path
        self.displayName = displayName
        self.category = category
        self.addedDate = addedDate
        self.modifiedDate = modifiedDate
        self.lastOpenedDate = lastOpenedDate
        self.isHidden = isHidden
    }
}

/// 应用网格支持的排序模式。
public enum AppSortMode: String, Codable, CaseIterable, Equatable, Sendable {
    /// 按添加时间从旧到新排序，新添加的软件排在后面。
    case addedDate

    /// 按名称本地化升序排序。
    case name

    /// 按最近打开时间从新到旧排序。
    case lastOpened

    /// 按用户保存的自定义顺序排序。
    case custom
}

/// 应用网格的展示方式。
public enum DisplayMode: String, Codable, CaseIterable, Equatable, Sendable {
    /// 分页网格，接近旧 Launchpad 的使用方式。
    case paged

    /// 垂直滚动网格，适合应用数量较多的用户。
    case scroll
}

/// 网格密度，决定每页或每屏能容纳的应用数量。
public enum GridDensity: String, Codable, CaseIterable, Equatable, Sendable {
    case small
    case medium
    case large

    /// 当前密度下的建议列数。
    public var columns: Int {
        switch self {
        case .small:
            return 9
        case .medium:
            return 7
        case .large:
            return 5
        }
    }

    /// 当前密度下的建议行数。
    public var rows: Int {
        switch self {
        case .small:
            return 6
        case .medium:
            return 5
        case .large:
            return 4
        }
    }
}

/// 全局快捷键配置，使用 Carbon/AppKit 兼容的键码与修饰键表示。
public struct Hotkey: Codable, Equatable, Hashable, Sendable {
    public var keyCode: UInt32
    public var modifiers: UInt32

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

/// OpenLaunch 的用户偏好设置。
public struct OpenLaunchSettings: Codable, Equatable, Sendable {
    public var sortMode: AppSortMode
    public var displayMode: DisplayMode
    public var gridDensity: GridDensity
    public var showLabels: Bool
    public var hotkey: Hotkey?
    public var customOrder: [String: Int]

    /// 首次启动或配置文件缺失时使用的默认设置。
    public static let `default` = OpenLaunchSettings(
        sortMode: .addedDate,
        displayMode: .paged,
        gridDensity: .medium,
        showLabels: true,
        hotkey: nil,
        customOrder: [:]
    )

    public init(
        sortMode: AppSortMode,
        displayMode: DisplayMode,
        gridDensity: GridDensity,
        showLabels: Bool,
        hotkey: Hotkey?,
        customOrder: [String: Int] = [:]
    ) {
        self.sortMode = sortMode
        self.displayMode = displayMode
        self.gridDensity = gridDensity
        self.showLabels = showLabels
        self.hotkey = hotkey
        self.customOrder = customOrder
    }
}
