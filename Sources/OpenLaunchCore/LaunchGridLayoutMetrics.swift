import CoreGraphics

/// 分页网格的共享布局参数，供界面绘制、点击兜底和测试共用。
public enum LaunchGridLayoutMetrics {
    public static let iconSize: CGFloat = 96
    public static let tileWidth: CGFloat = 146
    public static let labeledTileHeight: CGFloat = 146
    public static let iconOnlyTileHeight: CGFloat = 116
    public static let horizontalInset: CGFloat = 82
    public static let verticalInset: CGFloat = 18
    public static let minimumColumnSpacing: CGFloat = 22
    public static let maximumColumnSpacing: CGFloat = 70
    public static let minimumRowSpacing: CGFloat = 10
    public static let maximumRowSpacing: CGFloat = 30
    public static let headerHeight: CGFloat = 112
    public static let searchTopPadding: CGFloat = 60
    public static let footerHeight: CGFloat = 56
    public static let footerHitWidth: CGFloat = 260
    public static let searchHitWidth: CGFloat = 420
    public static let searchHitHeight: CGFloat = 58
    public static let searchControlHeight: CGFloat = 44
    public static let searchTextFieldHeight: CGFloat = 22
    public static let headerControlSpacing: CGFloat = 12
    public static let dockRevealInset: CGFloat = 24
    public static let pageGestureMinimumDistance: CGFloat = 4
    public static let pageSpacing: CGFloat = 80
    public static let pageTurnAnimationDuration: CGFloat = 0.32
    public static let pageGestureIdleFinishDelay: Double = 0.14

    /// 计算分页模式下指定应用图标的中心点，坐标系为网格区域左上角。
    public static func position(for index: Int, in size: CGSize, settings: OpenLaunchSettings) -> CGPoint {
        let columns = max(settings.gridDensity.columns, 1)
        let rows = max(settings.gridDensity.rows, 1)
        let column = index % columns
        let row = index / columns
        let tileHeight = settings.showLabels ? labeledTileHeight : iconOnlyTileHeight
        let availableWidth = max(size.width - horizontalInset * 2, tileWidth * CGFloat(columns))
        let columnSpacing = columns > 1
            ? max(minimumColumnSpacing, min(maximumColumnSpacing, (availableWidth - tileWidth * CGFloat(columns)) / CGFloat(columns - 1)))
            : 0
        let gridWidth = tileWidth * CGFloat(columns) + columnSpacing * CGFloat(columns - 1)
        let x = (size.width - gridWidth) / 2
            + tileWidth / 2
            + CGFloat(column) * (tileWidth + columnSpacing)

        let availableHeight = max(size.height - verticalInset * 2, tileHeight * CGFloat(rows))
        let rowSpacing = rows > 1
            ? max(minimumRowSpacing, min(maximumRowSpacing, (availableHeight - tileHeight * CGFloat(rows)) / CGFloat(rows - 1)))
            : 0
        let y = verticalInset
            + tileHeight / 2
            + CGFloat(row) * (tileHeight + rowSpacing)

        return CGPoint(x: x, y: y)
    }

    /// 返回图标按钮的命中区域，坐标系为窗口左上角。
    public static func tileHitFrame(for index: Int, windowSize: CGSize, settings: OpenLaunchSettings) -> CGRect {
        let gridHeight = max(windowSize.height - headerHeight - footerHeight, 0)
        let position = position(for: index, in: CGSize(width: windowSize.width, height: gridHeight), settings: settings)
        let tileHeight = settings.showLabels ? labeledTileHeight : iconOnlyTileHeight
        return CGRect(
            x: position.x - tileWidth / 2 - 12,
            y: headerHeight + position.y - tileHeight / 2 - 10,
            width: tileWidth + 24,
            height: tileHeight + 20
        )
    }

    /// 搜索框附近区域，避免点击搜索框或其焦点环时触发背景退出。
    public static func searchHitFrame(windowSize: CGSize) -> CGRect {
        let headerWidth = searchHitWidth + headerControlSpacing + searchControlHeight
        return CGRect(
            x: (windowSize.width - headerWidth) / 2,
            y: searchTopPadding - 18,
            width: searchHitWidth,
            height: searchHitHeight
        )
    }

    /// 设置按钮附近区域，避免点击设置菜单入口时触发背景退出。
    public static func settingsHitFrame(windowSize: CGSize) -> CGRect {
        let searchFrame = searchHitFrame(windowSize: windowSize)
        return CGRect(
            x: searchFrame.maxX + headerControlSpacing,
            y: searchFrame.minY,
            width: searchControlHeight,
            height: searchHitHeight
        )
    }

    /// 底部分页圆点附近区域。
    public static func footerHitFrame(windowSize: CGSize) -> CGRect {
        CGRect(
            x: (windowSize.width - footerHitWidth) / 2,
            y: max(windowSize.height - footerHeight - 20, 0),
            width: footerHitWidth,
            height: footerHeight + 18
        )
    }
}

/// 将窗口内点击解释为保留启动器或点击空白退出，作为 SwiftUI 透明层点击的兜底。
public enum LauncherBlankClickInterpreter {
    public enum Action: Equatable {
        case keepLauncher
        case hideLauncher
    }

    public static func action(
        at point: CGPoint,
        windowSize: CGSize,
        settings: OpenLaunchSettings,
        displayedAppCount: Int
    ) -> Action {
        if LaunchGridLayoutMetrics.searchHitFrame(windowSize: windowSize).contains(point)
            || LaunchGridLayoutMetrics.settingsHitFrame(windowSize: windowSize).contains(point)
            || LaunchGridLayoutMetrics.footerHitFrame(windowSize: windowSize).contains(point) {
            return .keepLauncher
        }

        for index in 0..<max(displayedAppCount, 0) {
            if LaunchGridLayoutMetrics.tileHitFrame(for: index, windowSize: windowSize, settings: settings).contains(point) {
                return .keepLauncher
            }
        }

        return .hideLauncher
    }
}

/// OpenLaunch 全屏覆盖层的系统栏策略：主内容窗口低于 Dock，不再创建顶部菜单栏遮罩窗口。
public enum LauncherChromePolicy {
    public static let contentWindowLevelRawValue = CGWindowLevelForKey(.dockWindow) - 1
    public static let usesMenuBarShield = false
    public static let initialPresentationDelayNanoseconds: UInt64 = 220_000_000
    public static let ordersWindowFrontRegardless = true
    public static let hidesOnApplicationResignActive = false
    public static let usesWindowAlphaFadeOnPresentation = false
    public static let usesMainQueueForInitialPresentation = true
    public static let requiresActiveApplicationForMenuBarHiding = true
    public static let usesRegularActivationDuringPresentation = true
    public static let usesAutoHideSystemBars = true
    public static let usesForcedMenuBarHiding = false
    public static let usesTransparentMenuBarTriggerShield = true
    public static let menuBarTriggerShieldHeight: CGFloat = 48
    public static let hidesStatusItemWhileLauncherVisible = true
    public static let returnsToAccessoryImmediatelyAfterPresentation = false
    public static let returnsToAccessoryAfterHiding = true
    public static let externalActivationSuppressionAfterPresentationNanoseconds: UInt64 = 500_000_000
}

/// 设置菜单策略：使用 AppKit 原生菜单，避免 SwiftUI 菜单行吞掉功能图标。
public enum SettingsMenuPolicy {
    public static let usesNativePickerSelection = false
    public static let showsSortGroupsInRootMenu = true
    public static let usesExplicitMenuSeparators = true
}
