import Foundation

/// 可被 OpenLaunch 展示和启动的 macOS 应用记录。
public struct LaunchableApp: Identifiable, Codable, Equatable, Hashable, Sendable {
    /// 应用的 bundle identifier；读取失败时允许为空。
    public let bundleIdentifier: String?

    /// `.app` bundle 在文件系统中的绝对路径。
    public let path: String

    /// 展示给用户看的应用名称。
    public var displayName: String

    /// 用于搜索的备用名称，例如原始英文名或 `.app` 文件名。
    public var searchAliases: [String]

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
        searchAliases: [String] = [],
        category: String? = nil,
        addedDate: Date?,
        modifiedDate: Date? = nil,
        lastOpenedDate: Date? = nil,
        isHidden: Bool = false
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.path = path
        self.displayName = displayName
        self.searchAliases = searchAliases
        self.category = category
        self.addedDate = addedDate
        self.modifiedDate = modifiedDate
        self.lastOpenedDate = lastOpenedDate
        self.isHidden = isHidden
    }

    /// 判断应用是否匹配搜索输入；展示名、本地别名和 bundle identifier 均可命中。
    public func matchesSearchQuery(_ query: String) -> Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return true
        }

        if displayName.localizedCaseInsensitiveContains(trimmedQuery) {
            return true
        }

        if searchAliases.contains(where: { $0.localizedCaseInsensitiveContains(trimmedQuery) }) {
            return true
        }

        return bundleIdentifier?.localizedCaseInsensitiveContains(trimmedQuery) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case bundleIdentifier
        case path
        case displayName
        case searchAliases
        case category
        case addedDate
        case modifiedDate
        case lastOpenedDate
        case isHidden
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        bundleIdentifier = try container.decodeIfPresent(String.self, forKey: .bundleIdentifier)
        path = try container.decode(String.self, forKey: .path)
        displayName = try container.decode(String.self, forKey: .displayName)
        searchAliases = try container.decodeIfPresent([String].self, forKey: .searchAliases) ?? []
        category = try container.decodeIfPresent(String.self, forKey: .category)
        addedDate = try container.decodeIfPresent(Date.self, forKey: .addedDate)
        modifiedDate = try container.decodeIfPresent(Date.self, forKey: .modifiedDate)
        lastOpenedDate = try container.decodeIfPresent(Date.self, forKey: .lastOpenedDate)
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(bundleIdentifier, forKey: .bundleIdentifier)
        try container.encode(path, forKey: .path)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(searchAliases, forKey: .searchAliases)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(addedDate, forKey: .addedDate)
        try container.encodeIfPresent(modifiedDate, forKey: .modifiedDate)
        try container.encodeIfPresent(lastOpenedDate, forKey: .lastOpenedDate)
        try container.encode(isHidden, forKey: .isHidden)
    }
}

/// 应用网格支持的排序模式。
public enum AppSortMode: String, Codable, CaseIterable, Equatable, Sendable {
    /// 按添加时间从旧到新排序，新添加的软件排在后面。
    case addedDate

    /// 按名称本地化升序排序。
    case name

    /// 按最近打开时间从旧到新排序，刚打开的应用排在后面。
    case lastOpened

    /// 按用户保存的自定义顺序排序。
    case custom
}

/// 排序方向；用于在保持同一排序方式的前提下切换正序/倒序。
public enum AppSortDirection: String, Codable, CaseIterable, Equatable, Sendable {
    /// 使用当前排序方式的默认正向顺序。
    case forward

    /// 使用当前排序方式的反向顺序。
    case reverse
}

/// 菜单中可直接选择的完整排序意图，避免用户分别设置排序方式和方向。
public struct AppSortSelection: Hashable, Identifiable, Sendable {
    public let mode: AppSortMode
    public let direction: AppSortDirection?
    public let title: String
    public let systemImageName: String

    public var id: String {
        if let direction {
            return "\(mode.rawValue).\(direction.rawValue)"
        }
        return mode.rawValue
    }

    public static let addedDateForward = AppSortSelection(
        mode: .addedDate,
        direction: .forward,
        title: "最早添加",
        systemImageName: "arrow.down"
    )

    public static let addedDateReverse = AppSortSelection(
        mode: .addedDate,
        direction: .reverse,
        title: "最近添加",
        systemImageName: "arrow.up"
    )

    public static let nameForward = AppSortSelection(
        mode: .name,
        direction: .forward,
        title: "A 到 Z",
        systemImageName: "arrow.down"
    )

    public static let nameReverse = AppSortSelection(
        mode: .name,
        direction: .reverse,
        title: "Z 到 A",
        systemImageName: "arrow.up"
    )

    public static let lastOpenedForward = AppSortSelection(
        mode: .lastOpened,
        direction: .forward,
        title: "最早打开",
        systemImageName: "arrow.down"
    )

    public static let lastOpenedReverse = AppSortSelection(
        mode: .lastOpened,
        direction: .reverse,
        title: "最近打开",
        systemImageName: "arrow.up"
    )

    public static let custom = AppSortSelection(
        mode: .custom,
        direction: nil,
        title: "自定义",
        systemImageName: "arrow.up.arrow.down.square"
    )

    public static var allCases: [AppSortSelection] {
        AppSortMenuLayout.groups.flatMap(\.options)
    }

    public static func current(for settings: OpenLaunchSettings) -> AppSortSelection {
        guard settings.sortMode != .custom else {
            return .custom
        }

        return allCases.first {
            $0.mode == settings.sortMode && $0.direction == settings.sortDirection
        } ?? .addedDateForward
    }

    public static func option(withID id: String) -> AppSortSelection? {
        allCases.first { $0.id == id }
    }
}

/// 排序菜单的二级分组，用于主界面设置入口保持一致的排序呈现。
public struct AppSortMenuGroup: Identifiable, Equatable, Sendable {
    public let mode: AppSortMode
    public let title: String
    public let systemImageName: String
    public let options: [AppSortSelection]

    public var id: AppSortMode {
        mode
    }
}

public enum AppSortMenuLayout {
    public static let groups: [AppSortMenuGroup] = [
        AppSortMenuGroup(
            mode: .addedDate,
            title: "添加时间",
            systemImageName: "calendar.badge.plus",
            options: [.addedDateForward, .addedDateReverse]
        ),
        AppSortMenuGroup(
            mode: .name,
            title: "名称",
            systemImageName: "textformat",
            options: [.nameForward, .nameReverse]
        ),
        AppSortMenuGroup(
            mode: .lastOpened,
            title: "最近打开",
            systemImageName: "clock.arrow.circlepath",
            options: [.lastOpenedForward, .lastOpenedReverse]
        ),
        AppSortMenuGroup(
            mode: .custom,
            title: "自定义",
            systemImageName: "arrow.up.arrow.down.square",
            options: [.custom]
        )
    ]
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
    public var sortDirection: AppSortDirection
    public var displayMode: DisplayMode
    public var gridDensity: GridDensity
    public var showLabels: Bool
    public var hotkey: Hotkey?
    public var customOrder: [String: Int]

    /// 首次启动或配置文件缺失时使用的默认设置。
    public static let `default` = OpenLaunchSettings(
        sortMode: .addedDate,
        sortDirection: .forward,
        displayMode: .paged,
        gridDensity: .medium,
        showLabels: true,
        hotkey: nil,
        customOrder: [:]
    )

    public init(
        sortMode: AppSortMode,
        sortDirection: AppSortDirection = .forward,
        displayMode: DisplayMode,
        gridDensity: GridDensity,
        showLabels: Bool,
        hotkey: Hotkey?,
        customOrder: [String: Int] = [:]
    ) {
        self.sortMode = sortMode
        self.sortDirection = sortDirection
        self.displayMode = displayMode
        self.gridDensity = gridDensity
        self.showLabels = showLabels
        self.hotkey = hotkey
        self.customOrder = customOrder
    }

    enum CodingKeys: String, CodingKey {
        case sortMode
        case sortDirection
        case displayMode
        case gridDensity
        case showLabels
        case hotkey
        case customOrder
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sortMode = try container.decode(AppSortMode.self, forKey: .sortMode)
        sortDirection = try container.decodeIfPresent(AppSortDirection.self, forKey: .sortDirection) ?? .forward
        displayMode = try container.decode(DisplayMode.self, forKey: .displayMode)
        gridDensity = try container.decode(GridDensity.self, forKey: .gridDensity)
        showLabels = try container.decode(Bool.self, forKey: .showLabels)
        hotkey = try container.decodeIfPresent(Hotkey.self, forKey: .hotkey)
        customOrder = try container.decodeIfPresent([String: Int].self, forKey: .customOrder) ?? [:]
    }
}
