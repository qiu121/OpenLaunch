import AppKit
import OpenLaunchCore
import QuartzCore
import SwiftUI

/// 将触控板二维滚动转换为分页主轴输入，避免轻微斜向手势在起步阶段被丢弃。
enum PagingScrollInput {
    /// 系统触控板增量相对整屏宽度偏小，放大后慢速手势可以自然拖动到半页。
    static let trackingGain: CGFloat = 2

    static func trackingDelta(horizontal: CGFloat, vertical: CGFloat) -> CGFloat {
        let primaryDelta = abs(horizontal) > abs(vertical) ? horizontal : vertical
        return primaryDelta * trackingGain
    }

    /// `.began` 事件也可能携带首帧位移；仅在手势明确结束时停止累计。
    static func tracksDelta(during phase: NSEvent.Phase) -> Bool {
        !phase.contains(.ended) && !phase.contains(.cancelled)
    }
}

/// SwiftUI 手势与 AppKit 分页轨道之间的轻量桥接，不通过全局可观察状态传递高频位移。
@MainActor
final class InteractivePagingProxy: ObservableObject {
    private weak var target: InteractivePagingTarget?

    fileprivate func connect(to target: InteractivePagingTarget) {
        self.target = target
    }

    func updatePointerGesture(translation: CGSize) {
        target?.updatePointerGesture(
            translation: translation,
            timestamp: ProcessInfo.processInfo.systemUptime
        )
    }

    func endPointerGesture(translation: CGSize) {
        target?.endPointerGesture(
            translation: translation,
            timestamp: ProcessInfo.processInfo.systemUptime
        )
    }

    func cancelPointerGesture() {
        target?.cancelPointerGesture()
    }

    func resetAfterLauncherHides() {
        target?.resetAfterLauncherHides()
    }
}

/// 使用 AppKit 宿主承载 SwiftUI 页面，并通过可命中测试的坐标滚动整条页面轨道。
struct InteractivePagedGrid<Content: View>: NSViewRepresentable {
    let currentPage: Int
    let pageCount: Int
    let pageSpacing: CGFloat
    let proxy: InteractivePagingProxy
    let onPageChanged: (Int) -> Void
    let content: Content

    init(
        currentPage: Int,
        pageCount: Int,
        pageSpacing: CGFloat,
        proxy: InteractivePagingProxy,
        onPageChanged: @escaping (Int) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.currentPage = currentPage
        self.pageCount = pageCount
        self.pageSpacing = pageSpacing
        self.proxy = proxy
        self.onPageChanged = onPageChanged
        self.content = content()
    }

    func makeNSView(context: Context) -> InteractivePagingHostView {
        let view = InteractivePagingHostView(rootView: AnyView(content))
        view.update(
            rootView: AnyView(content),
            currentPage: currentPage,
            pageCount: pageCount,
            pageSpacing: pageSpacing,
            onPageChanged: onPageChanged
        )
        proxy.connect(to: view)
        return view
    }

    func updateNSView(_ nsView: InteractivePagingHostView, context: Context) {
        nsView.update(
            rootView: AnyView(content),
            currentPage: currentPage,
            pageCount: pageCount,
            pageSpacing: pageSpacing,
            onPageChanged: onPageChanged
        )
        proxy.connect(to: nsView)
    }

    static func dismantleNSView(_ nsView: InteractivePagingHostView, coordinator: Void) {
        nsView.tearDown()
    }
}

@MainActor
fileprivate protocol InteractivePagingTarget: AnyObject {
    func updatePointerGesture(translation: CGSize, timestamp: TimeInterval)
    func endPointerGesture(translation: CGSize, timestamp: TimeInterval)
    func cancelPointerGesture()
    func resetAfterLauncherHides()
}

@MainActor
final class InteractivePagingHostView: NSView, InteractivePagingTarget {
    private enum Constants {
        static let settleSnapDistance: CGFloat = 0.5
    }

    private let hostingView: NSHostingView<AnyView>
    private var pageCount = 1
    private var currentPage = 0
    private var pageSpacing: CGFloat = 0
    private var trackOffset: CGFloat = 0
    private var previousPageStride: CGFloat = 1
    private var scrollMonitor: Any?
    private var scrollIdleWorkItem: DispatchWorkItem?
    private var scrollSession: InteractivePagingSession?
    private var pointerSession: InteractivePagingSession?
    private var lastPointerTranslation: CGSize = .zero
    private var settleDisplayLink: CADisplayLink?
    private var settleTargetOffset: CGFloat?
    private var lastSettleFrameTime: CFTimeInterval?
    private var discreteWheelGate = DiscretePagingWheelGate()
    private var onPageChanged: ((Int) -> Void)?

    init(rootView: AnyView) {
        self.hostingView = NSHostingView(rootView: rootView)
        super.init(frame: .zero)

        wantsLayer = true
        layer?.masksToBounds = true
        hostingView.wantsLayer = true
        addSubview(hostingView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if window == nil {
            removeScrollMonitor()
            removeSettleDisplayLink()
        } else {
            installScrollMonitor()
            installSettleDisplayLink()
        }
    }

    override func layout() {
        super.layout()

        let stride = pageStride
        let trackWidth = bounds.width * CGFloat(pageCount) + pageSpacing * CGFloat(max(pageCount - 1, 0))
        hostingView.frame = NSRect(x: 0, y: 0, width: trackWidth, height: bounds.height)

        guard abs(stride - previousPageStride) > 0.5 else {
            return
        }

        previousPageStride = stride
        cancelActiveInput()
        setTrackOffset(offset(for: currentPage))
    }

    func update(
        rootView: AnyView,
        currentPage requestedPage: Int,
        pageCount requestedPageCount: Int,
        pageSpacing: CGFloat,
        onPageChanged: @escaping (Int) -> Void
    ) {
        hostingView.rootView = rootView
        self.onPageChanged = onPageChanged

        let validPageCount = max(requestedPageCount, 1)
        let validPage = min(max(requestedPage, 0), validPageCount - 1)
        let structureChanged = validPageCount != pageCount || pageSpacing != self.pageSpacing

        pageCount = validPageCount
        self.pageSpacing = pageSpacing

        if structureChanged {
            currentPage = validPage
            cancelActiveInput()
            needsLayout = true
            layoutSubtreeIfNeeded()
            setTrackOffset(offset(for: currentPage))
            return
        }

        guard validPage != currentPage else {
            return
        }

        navigate(to: validPage, notifiesState: false)
    }

    func tearDown() {
        removeScrollMonitor()
        removeSettleDisplayLink()
        cancelActiveInput()
        onPageChanged = nil
    }

    func updatePointerGesture(translation: CGSize, timestamp: TimeInterval) {
        if pointerSession == nil {
            beginPointerGesture(timestamp: timestamp)
        }

        guard var session = pointerSession else {
            return
        }

        let delta = CGSize(
            width: translation.width - lastPointerTranslation.width,
            height: translation.height - lastPointerTranslation.height
        )
        lastPointerTranslation = translation

        let update = session.append(
            deltaX: delta.width,
            deltaY: delta.height,
            timestamp: timestamp
        )
        pointerSession = session
        apply(update)
    }

    func endPointerGesture(translation: CGSize, timestamp: TimeInterval) {
        guard pointerSession != nil else {
            return
        }

        updatePointerGesture(translation: translation, timestamp: timestamp)
        finishPointerGesture(timestamp: timestamp)
    }

    func cancelPointerGesture() {
        guard let session = pointerSession else {
            return
        }

        pointerSession = nil
        lastPointerTranslation = .zero
        settle(using: session.cancel())
    }

    func resetAfterLauncherHides() {
        cancelActiveInput()
        setTrackOffset(offset(for: currentPage))
    }

    private var pageStride: CGFloat {
        max(bounds.width + pageSpacing, 1)
    }

    private func offset(for page: Int) -> CGFloat {
        -CGFloat(page) * pageStride
    }

    private func beginPointerGesture(timestamp: TimeInterval) {
        stopSettleAnimation()
        lastPointerTranslation = .zero
        pointerSession = makeSession(startedAt: timestamp, allowsFlickPrediction: false)
    }

    private func finishPointerGesture(timestamp: TimeInterval) {
        guard let session = pointerSession else {
            return
        }

        pointerSession = nil
        lastPointerTranslation = .zero
        settle(using: session.end(at: timestamp))
    }

    private func makeSession(
        startedAt timestamp: TimeInterval,
        allowsFlickPrediction: Bool
    ) -> InteractivePagingSession {
        InteractivePagingSession(
            currentPage: currentPage,
            pageCount: pageCount,
            pageStride: pageStride,
            startedAt: timestamp,
            initialOffset: trackOffset,
            allowsFlickPrediction: allowsFlickPrediction
        )
    }

    private func installScrollMonitor() {
        removeScrollMonitor()

        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self,
                  let targetWindow = self.window,
                  targetWindow.isVisible,
                  targetWindow.isKeyWindow else {
                return event
            }

            if let eventWindow = event.window, eventWindow !== targetWindow {
                return event
            }

            let pointInWindow: NSPoint
            if event.window == nil {
                pointInWindow = targetWindow.convertPoint(fromScreen: NSEvent.mouseLocation)
            } else {
                pointInWindow = event.locationInWindow
            }

            let point = self.convert(pointInWindow, from: nil)
            guard self.bounds.contains(point) else {
                return event
            }

            return self.handleScrollWheel(event) ? nil : event
        }
    }

    private func removeScrollMonitor() {
        if let scrollMonitor {
            NSEvent.removeMonitor(scrollMonitor)
            self.scrollMonitor = nil
        }
    }

    private func handleScrollWheel(_ event: NSEvent) -> Bool {
        if !event.hasPreciseScrollingDeltas {
            return handleDiscreteWheel(event)
        }

        let gestureEnded = event.phase.contains(.ended)
        let gestureCancelled = event.phase.contains(.cancelled)
        let gestureFinished = gestureEnded || gestureCancelled
        if event.momentumPhase != [], !gestureFinished {
            if scrollSession != nil {
                finishScrollGesture(timestamp: event.timestamp)
            }
            return true
        }

        if event.phase.contains(.began) || scrollSession == nil {
            beginScrollGesture(timestamp: event.timestamp)
        }

        var consumed = true
        let trackingDelta = PagingScrollInput.trackingDelta(
            horizontal: event.scrollingDeltaX,
            vertical: event.scrollingDeltaY
        )
        if PagingScrollInput.tracksDelta(during: event.phase),
           trackingDelta != 0,
           var session = scrollSession {
            let update = session.append(
                deltaX: trackingDelta,
                deltaY: 0,
                timestamp: event.timestamp
            )
            scrollSession = session
            consumed = apply(update)
        }

        if gestureCancelled {
            cancelScrollGesture()
        } else if gestureEnded {
            finishScrollGesture(timestamp: event.timestamp)
        } else if event.phase.isEmpty {
            scheduleScrollIdleFinish()
        }

        return consumed
    }

    private func handleDiscreteWheel(_ event: NSEvent) -> Bool {
        let delta = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
            ? event.scrollingDeltaX
            : event.scrollingDeltaY
        guard delta != 0 else {
            return false
        }

        let timestamp = ProcessInfo.processInfo.systemUptime
        guard discreteWheelGate.shouldTurnPage(at: timestamp) else {
            return true
        }

        let targetPage = delta < 0 ? currentPage + 1 : currentPage - 1
        let clampedPage = min(max(targetPage, 0), pageCount - 1)
        guard clampedPage != currentPage else {
            return true
        }

        navigate(to: clampedPage, notifiesState: true)
        return true
    }

    private func beginScrollGesture(timestamp: TimeInterval) {
        scrollIdleWorkItem?.cancel()
        stopSettleAnimation()
        scrollSession = makeSession(startedAt: timestamp, allowsFlickPrediction: true)
    }

    private func scheduleScrollIdleFinish() {
        scrollIdleWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.finishScrollGesture(timestamp: ProcessInfo.processInfo.systemUptime)
        }
        scrollIdleWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + LaunchGridLayoutMetrics.pageGestureIdleFinishDelay,
            execute: workItem
        )
    }

    private func finishScrollGesture(timestamp: TimeInterval) {
        scrollIdleWorkItem?.cancel()
        scrollIdleWorkItem = nil
        guard let session = scrollSession else {
            return
        }

        scrollSession = nil
        settle(using: session.end(at: timestamp))
    }

    private func cancelScrollGesture() {
        scrollIdleWorkItem?.cancel()
        scrollIdleWorkItem = nil
        guard let session = scrollSession else {
            return
        }

        scrollSession = nil
        settle(using: session.cancel())
    }

    @discardableResult
    private func apply(_ update: InteractivePagingUpdate) -> Bool {
        switch update {
        case .pending:
            return true
        case .passthrough:
            return false
        case .tracking(let offset):
            setTrackOffset(offset)
            return true
        }
    }

    private func settle(using resolution: InteractivePagingResolution) {
        navigate(
            to: resolution.targetPage,
            targetOffset: resolution.targetOffset,
            notifiesState: true
        )
    }

    private func navigate(to page: Int, notifiesState: Bool) {
        navigate(
            to: page,
            targetOffset: offset(for: page),
            notifiesState: notifiesState
        )
    }

    private func navigate(
        to page: Int,
        targetOffset: CGFloat,
        notifiesState: Bool
    ) {
        let validPage = min(max(page, 0), pageCount - 1)
        let pageChanged = validPage != currentPage
        currentPage = validPage

        if pageChanged, notifiesState {
            onPageChanged?(validPage)
        }

        animateTrack(to: targetOffset)
    }

    private func animateTrack(to targetOffset: CGFloat) {
        guard settleDisplayLink != nil,
              abs(targetOffset - trackOffset) > Constants.settleSnapDistance else {
            stopSettleAnimation()
            setTrackOffset(targetOffset)
            return
        }

        settleTargetOffset = targetOffset
        lastSettleFrameTime = CACurrentMediaTime()
        settleDisplayLink?.isPaused = false
    }

    private func setTrackOffset(_ offset: CGFloat) {
        trackOffset = offset

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        hostingView.setBoundsOrigin(NSPoint(x: -offset, y: 0))
        CATransaction.commit()
    }

    private func installSettleDisplayLink() {
        removeSettleDisplayLink()
        guard let window else {
            return
        }

        let displayLink = window.displayLink(target: self, selector: #selector(advanceSettleAnimation(_:)))
        displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        displayLink.isPaused = true
        displayLink.add(to: .main, forMode: .common)
        settleDisplayLink = displayLink
    }

    private func removeSettleDisplayLink() {
        settleDisplayLink?.invalidate()
        settleDisplayLink = nil
        stopSettleAnimation()
    }

    @objc private func advanceSettleAnimation(_ displayLink: CADisplayLink) {
        guard let targetOffset = settleTargetOffset else {
            return
        }

        let difference = targetOffset - trackOffset
        guard abs(difference) > Constants.settleSnapDistance else {
            setTrackOffset(targetOffset)
            stopSettleAnimation()
            return
        }

        let now = CACurrentMediaTime()
        let elapsed = now - (lastSettleFrameTime ?? now)
        lastSettleFrameTime = now
        let nextOffset = InteractivePagingSettleMotion.nextOffset(
            current: trackOffset,
            target: targetOffset,
            elapsed: elapsed
        )
        setTrackOffset(nextOffset)
    }

    private func stopSettleAnimation() {
        settleTargetOffset = nil
        lastSettleFrameTime = nil
        settleDisplayLink?.isPaused = true
    }

    private func cancelActiveInput() {
        scrollIdleWorkItem?.cancel()
        scrollIdleWorkItem = nil
        scrollSession = nil
        pointerSession = nil
        lastPointerTranslation = .zero
        discreteWheelGate.reset()
        stopSettleAnimation()
    }
}
