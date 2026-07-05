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
    public static let dockRevealInset: CGFloat = 24
    public static let pageDragThreshold: CGFloat = 28
    public static let pageSwipeThreshold: CGFloat = 12
    public static let pageTurnAnimationDuration: CGFloat = 0.26

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
        CGRect(
            x: (windowSize.width - searchHitWidth) / 2,
            y: searchTopPadding - 18,
            width: searchHitWidth,
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

/// 将触控板横向滑动或鼠标横向滚轮解释成分页方向。
public enum PageSwipeInterpreter {
    public enum Direction: Equatable {
        case previous
        case next
    }

    public static func direction(deltaX: CGFloat, deltaY: CGFloat) -> Direction? {
        guard abs(deltaX) >= LaunchGridLayoutMetrics.pageSwipeThreshold,
              abs(deltaX) > abs(deltaY) * 1.2 else {
            return nil
        }

        return deltaX < 0 ? .next : .previous
    }
}

/// 累积滚轮/触控板的连续小幅横向输入，避免单个事件过小导致分页不触发。
public struct PageSwipeAccumulator {
    private var accumulatedDeltaX: CGFloat = 0
    private var accumulatedDeltaY: CGFloat = 0
    private let threshold: CGFloat
    private let horizontalDominanceRatio: CGFloat

    public init(threshold: CGFloat = LaunchGridLayoutMetrics.pageDragThreshold, horizontalDominanceRatio: CGFloat = 1.2) {
        self.threshold = threshold
        self.horizontalDominanceRatio = horizontalDominanceRatio
    }

    public mutating func append(deltaX: CGFloat, deltaY: CGFloat) -> PageSwipeInterpreter.Direction? {
        accumulatedDeltaX += deltaX
        accumulatedDeltaY += deltaY

        if abs(accumulatedDeltaY) >= threshold,
           abs(accumulatedDeltaY) >= abs(accumulatedDeltaX) {
            reset()
            return nil
        }

        guard abs(accumulatedDeltaX) >= threshold,
              abs(accumulatedDeltaX) > abs(accumulatedDeltaY) * horizontalDominanceRatio else {
            return nil
        }

        let direction: PageSwipeInterpreter.Direction = accumulatedDeltaX < 0 ? .next : .previous
        reset()
        return direction
    }

    public mutating func reset() {
        accumulatedDeltaX = 0
        accumulatedDeltaY = 0
    }
}

/// 分页轨道的位移计算，模拟系统启动台整页横向滑动的连续运动。
public enum PageCarouselLayout {
    private static let edgeResistance: CGFloat = 0.24
    private static let predictedDragThreshold: CGFloat = 96

    /// 根据当前页、屏宽和拖拽距离计算横向轨道偏移。
    public static func offset(currentPage: Int, pageWidth: CGFloat, dragTranslation: CGFloat, pageCount: Int) -> CGFloat {
        guard pageWidth > 0, pageCount > 0 else {
            return 0
        }

        let clampedPage = min(max(currentPage, 0), pageCount - 1)
        let resistedTranslation = resistedDragTranslation(
            dragTranslation,
            currentPage: clampedPage,
            pageCount: pageCount
        )

        return -CGFloat(clampedPage) * pageWidth + resistedTranslation
    }

    /// 使用实际拖拽和系统预测拖拽共同判断目标翻页方向，让轻扫也能自然翻页。
    public static func targetDirection(
        translation: CGFloat,
        predictedTranslation: CGFloat,
        verticalTranslation: CGFloat
    ) -> PageSwipeInterpreter.Direction? {
        let effectiveTranslation = abs(predictedTranslation) > abs(translation)
            ? predictedTranslation
            : translation
        let threshold = abs(predictedTranslation) > abs(translation)
            ? predictedDragThreshold
            : LaunchGridLayoutMetrics.pageDragThreshold

        guard abs(effectiveTranslation) >= threshold,
              abs(effectiveTranslation) > abs(verticalTranslation) * 1.2 else {
            return nil
        }

        return effectiveTranslation < 0 ? .next : .previous
    }

    private static func resistedDragTranslation(_ dragTranslation: CGFloat, currentPage: Int, pageCount: Int) -> CGFloat {
        guard pageCount > 1 else {
            return 0
        }

        let isPullingPastFirstPage = currentPage == 0 && dragTranslation > 0
        let isPullingPastLastPage = currentPage == pageCount - 1 && dragTranslation < 0
        guard isPullingPastFirstPage || isPullingPastLastPage else {
            return dragTranslation
        }

        return dragTranslation * edgeResistance
    }
}
