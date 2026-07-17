import CoreGraphics
import Foundation

/// 连续分页手势在轴向判定阶段或跟踪阶段产生的结果。
public enum InteractivePagingUpdate: Equatable {
    case pending
    case passthrough
    case tracking(offset: CGFloat)
}

/// 手势释放后的吸附目标，供界面层执行统一的减速动画。
public struct InteractivePagingResolution: Equatable {
    public let targetPage: Int
    public let targetOffset: CGFloat

    public init(targetPage: Int, targetOffset: CGFloat) {
        self.targetPage = targetPage
        self.targetOffset = targetOffset
    }
}

/// 以 120Hz 下每帧保留 82% 距离为基准，并按实际帧间隔修正吸附速度。
public enum InteractivePagingSettleMotion {
    private static let nominalFramesPerSecond: Double = 120
    private static let retainedDistancePerFrame: Double = 0.82

    public static func nextOffset(
        current: CGFloat,
        target: CGFloat,
        elapsed: TimeInterval
    ) -> CGFloat {
        let boundedElapsed = min(max(elapsed, 1.0 / 240.0), 1.0 / 30.0)
        let frameCount = boundedElapsed * nominalFramesPerSecond
        let retainedDistance = pow(retainedDistancePerFrame, frameCount)
        return target - (target - current) * CGFloat(retainedDistance)
    }
}

/// 将连续滚轮事件识别为一次输入，避免一轮滚动跨越多个页面。
public struct DiscretePagingWheelGate {
    private let idleInterval: TimeInterval
    private var lastEventTimestamp: TimeInterval?

    public init(idleInterval: TimeInterval = 0.20) {
        self.idleInterval = max(idleInterval, 0)
    }

    public mutating func shouldTurnPage(at timestamp: TimeInterval) -> Bool {
        defer { lastEventTimestamp = timestamp }

        guard let lastEventTimestamp,
              timestamp >= lastEventTimestamp else {
            return true
        }

        return timestamp - lastEventTimestamp >= idleInterval
    }

    public mutating func reset() {
        lastEventTimestamp = nil
    }
}

/// 把触控板的增量事件转换为逐点跟随的页面轨道位置，并在释放时决定吸附页。
public struct InteractivePagingSession {
    private enum AxisLock {
        case pending
        case horizontal
        case vertical
    }

    private static let axisLockDistance: CGFloat = 4
    private static let horizontalDominanceRatio: CGFloat = 1.15
    private static let pageTurnProgress: CGFloat = 0.15
    private static let flickVelocityThreshold: CGFloat = 900
    private static let minimumFlickTravel: CGFloat = 48
    private static let flickRecencyWindow: TimeInterval = 0.08
    private static let velocitySmoothing: CGFloat = 0.35
    private static let rubberBandLimitRatio: CGFloat = 0.2
    private static let rubberBandStrength: CGFloat = 0.5

    private let currentPage: Int
    private let pageCount: Int
    private let pageStride: CGFloat
    private let baseOffset: CGFloat
    private let initialOffset: CGFloat
    private let allowsFlickPrediction: Bool
    private var axisLock: AxisLock = .pending
    private var translationX: CGFloat = 0
    private var translationY: CGFloat = 0
    private var currentOffset: CGFloat
    private var velocityX: CGFloat = 0
    private var lastTimestamp: TimeInterval

    public init(
        currentPage: Int,
        pageCount: Int,
        pageStride: CGFloat,
        startedAt: TimeInterval,
        initialOffset: CGFloat? = nil,
        allowsFlickPrediction: Bool = true
    ) {
        let validPageCount = max(pageCount, 1)
        let validCurrentPage = min(max(currentPage, 0), validPageCount - 1)
        let validPageStride = max(pageStride, 1)

        self.currentPage = validCurrentPage
        self.pageCount = validPageCount
        self.pageStride = validPageStride
        self.baseOffset = -CGFloat(validCurrentPage) * validPageStride
        let resolvedInitialOffset = initialOffset ?? self.baseOffset
        self.initialOffset = resolvedInitialOffset
        self.allowsFlickPrediction = allowsFlickPrediction
        self.currentOffset = resolvedInitialOffset
        self.lastTimestamp = startedAt
    }

    /// 追加一次触控板增量；横向锁定后，返回与手势一一对应的页面轨道位置。
    public mutating func append(
        deltaX: CGFloat,
        deltaY: CGFloat,
        timestamp: TimeInterval
    ) -> InteractivePagingUpdate {
        guard axisLock != .vertical else {
            return .passthrough
        }

        translationX += deltaX
        translationY += deltaY
        updateVelocity(deltaX: deltaX, timestamp: timestamp)

        if axisLock == .pending {
            let distance = hypot(translationX, translationY)
            guard distance >= Self.axisLockDistance else {
                return .pending
            }

            guard abs(translationX) > abs(translationY) * Self.horizontalDominanceRatio else {
                axisLock = .vertical
                return .passthrough
            }

            axisLock = .horizontal
        }

        currentOffset = trackOffset(for: translationX)
        return .tracking(offset: currentOffset)
    }

    /// 结束手势。位移或速度达到条件时只前进到相邻页，否则返回当前页。
    public func end(at timestamp: TimeInterval) -> InteractivePagingResolution {
        guard axisLock == .horizontal else {
            return resolution(for: currentPage)
        }

        let progress = translationX / pageStride
        let hasDistanceIntent = abs(progress) >= Self.pageTurnProgress
        let hasRecentVelocity = timestamp - lastTimestamp <= Self.flickRecencyWindow
        let hasFlickIntent = allowsFlickPrediction
            && hasRecentVelocity
            && abs(translationX) >= Self.minimumFlickTravel
            && abs(velocityX) >= Self.flickVelocityThreshold
        guard hasDistanceIntent || hasFlickIntent else {
            return resolution(for: currentPage)
        }

        let directionSource = hasFlickIntent ? velocityX : translationX
        let proposedPage = directionSource < 0 ? currentPage + 1 : currentPage - 1
        return resolution(for: min(max(proposedPage, 0), pageCount - 1))
    }

    /// 取消手势时忽略已累计的距离和速度，始终回到手势开始时的页面。
    public func cancel() -> InteractivePagingResolution {
        resolution(for: currentPage)
    }

    private mutating func updateVelocity(deltaX: CGFloat, timestamp: TimeInterval) {
        defer { lastTimestamp = timestamp }

        let elapsed = timestamp - lastTimestamp
        guard elapsed > 0, elapsed <= 0.10 else {
            velocityX = 0
            return
        }

        let sampleDuration = max(elapsed, 1.0 / 240.0)
        let instantaneousVelocity = deltaX / CGFloat(sampleDuration)
        if velocityX == 0 {
            velocityX = instantaneousVelocity
        } else {
            velocityX += (instantaneousVelocity - velocityX) * Self.velocitySmoothing
        }
    }

    private func trackOffset(for translation: CGFloat) -> CGFloat {
        let proposedOffset = initialOffset + translation
        let minimumOffset = -CGFloat(pageCount - 1) * pageStride
        let maximumOffset: CGFloat = 0

        if proposedOffset > maximumOffset {
            return rubberBand(distance: proposedOffset - maximumOffset) + maximumOffset
        }

        if proposedOffset < minimumOffset {
            return minimumOffset - rubberBand(distance: minimumOffset - proposedOffset)
        }

        let previousPageOffset = baseOffset + pageStride
        let nextPageOffset = baseOffset - pageStride
        return min(max(proposedOffset, nextPageOffset), previousPageOffset)
    }

    private func rubberBand(distance: CGFloat) -> CGFloat {
        let limit = pageStride * Self.rubberBandLimitRatio
        return Self.rubberBandStrength * distance * limit / (distance + limit)
    }

    private func resolution(for targetPage: Int) -> InteractivePagingResolution {
        let targetOffset = -CGFloat(targetPage) * pageStride
        return InteractivePagingResolution(
            targetPage: targetPage,
            targetOffset: targetOffset
        )
    }
}
