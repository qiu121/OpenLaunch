import CoreGraphics
import XCTest
@testable import OpenLaunchCore

final class InteractivePagingSessionTests: XCTestCase {
    func testHorizontalGestureTracksEverySuppliedDelta() {
        var session = makeSession(currentPage: 1)

        XCTAssertEqual(session.append(deltaX: -3, deltaY: 0, timestamp: 0.01), .pending)
        XCTAssertEqual(session.append(deltaX: -27, deltaY: 1, timestamp: 0.02), .tracking(offset: -1_030))
        XCTAssertEqual(session.append(deltaX: -70, deltaY: 1, timestamp: 0.03), .tracking(offset: -1_100))
    }

    func testTinyDeltasBecomeVisibleAsSoonAsTheAxisLocks() {
        var session = makeSession(currentPage: 1)

        XCTAssertEqual(session.append(deltaX: -1, deltaY: 0, timestamp: 0.01), .pending)
        XCTAssertEqual(session.append(deltaX: -1, deltaY: 0, timestamp: 0.02), .pending)
        XCTAssertEqual(session.append(deltaX: -1, deltaY: 0, timestamp: 0.03), .pending)
        XCTAssertEqual(
            session.append(deltaX: -1, deltaY: 0, timestamp: 0.04),
            .tracking(offset: -1_004)
        )
    }

    func testVerticalGestureIsRejectedBeforePagingStarts() {
        var session = makeSession(currentPage: 1)

        XCTAssertEqual(session.append(deltaX: 2, deltaY: 3, timestamp: 0.01), .pending)
        XCTAssertEqual(session.append(deltaX: 2, deltaY: 12, timestamp: 0.02), .passthrough)
        XCTAssertEqual(session.append(deltaX: -80, deltaY: 0, timestamp: 0.03), .passthrough)
    }

    func testSlowDragPastFifteenPercentSettlesOnAdjacentPage() {
        var session = makeSession(currentPage: 1)

        _ = session.append(deltaX: -80, deltaY: 2, timestamp: 0.20)
        _ = session.append(deltaX: -80, deltaY: 2, timestamp: 0.40)

        let resolution = session.end(at: 0.60)

        XCTAssertEqual(resolution.targetPage, 2)
        XCTAssertEqual(resolution.targetOffset, -2_000)
    }

    func testSlowDragBelowThresholdReturnsToCurrentPage() {
        var session = makeSession(currentPage: 1)

        _ = session.append(deltaX: -60, deltaY: 2, timestamp: 0.20)
        _ = session.append(deltaX: -60, deltaY: 2, timestamp: 0.40)

        let resolution = session.end(at: 0.60)

        XCTAssertEqual(resolution.targetPage, 1)
        XCTAssertEqual(resolution.targetOffset, -1_000)
    }

    func testFastShortFlickSettlesOnAdjacentPage() {
        var session = makeSession(currentPage: 1)

        _ = session.append(deltaX: -20, deltaY: 1, timestamp: 0.02)
        _ = session.append(deltaX: -30, deltaY: 1, timestamp: 0.04)

        XCTAssertEqual(session.end(at: 0.05).targetPage, 2)
    }

    func testTinyFastMovementReturnsToCurrentPage() {
        var session = makeSession(currentPage: 1)

        _ = session.append(deltaX: -20, deltaY: 0, timestamp: 0.02)

        XCTAssertEqual(session.end(at: 0.03).targetPage, 1)
    }

    func testCancelledGestureAlwaysReturnsToCurrentPage() {
        var session = makeSession(currentPage: 1)

        _ = session.append(deltaX: -400, deltaY: 0, timestamp: 0.10)

        XCTAssertEqual(session.cancel().targetPage, 1)
        XCTAssertEqual(session.cancel().targetOffset, -1_000)
    }

    func testDiscreteWheelGateAllowsOnlyOneTurnPerContinuousBurst() {
        var gate = DiscretePagingWheelGate(idleInterval: 0.20)

        XCTAssertTrue(gate.shouldTurnPage(at: 1.00))
        XCTAssertFalse(gate.shouldTurnPage(at: 1.10))
        XCTAssertFalse(gate.shouldTurnPage(at: 1.25))
        XCTAssertTrue(gate.shouldTurnPage(at: 1.46))
    }

    func testDiscreteWheelGateResetAllowsImmediateTurn() {
        var gate = DiscretePagingWheelGate(idleInterval: 0.20)

        XCTAssertTrue(gate.shouldTurnPage(at: 1.00))
        XCTAssertFalse(gate.shouldTurnPage(at: 1.10))
        gate.reset()

        XCTAssertTrue(gate.shouldTurnPage(at: 1.11))
    }

    func testSingleGestureNeverSkipsMoreThanOnePage() {
        var session = makeSession(currentPage: 1, pageCount: 5)

        _ = session.append(deltaX: -2_600, deltaY: 0, timestamp: 0.10)

        XCTAssertEqual(session.end(at: 0.20).targetPage, 2)
    }

    func testDraggingBackTowardStartReversesOneToOne() {
        var session = makeSession(currentPage: 1)

        _ = session.append(deltaX: -200, deltaY: 0, timestamp: 0.10)
        let update = session.append(deltaX: 125, deltaY: 0, timestamp: 0.20)

        XCTAssertEqual(update, .tracking(offset: -1_075))
    }

    func testEdgeOverscrollUsesNonlinearResistance() {
        var session = makeSession(currentPage: 0)

        let first = session.append(deltaX: 100, deltaY: 0, timestamp: 0.10)
        let second = session.append(deltaX: 100, deltaY: 0, timestamp: 0.20)

        guard case .tracking(let firstOffset) = first,
              case .tracking(let secondOffset) = second else {
            return XCTFail("边界拖动应进入分页跟踪状态")
        }

        XCTAssertGreaterThan(firstOffset, 0)
        XCTAssertLessThan(firstOffset, 100)
        XCTAssertGreaterThan(secondOffset, firstOffset)
        XCTAssertLessThan(secondOffset - firstOffset, firstOffset)
        XCTAssertEqual(session.end(at: 0.30).targetPage, 0)
    }

    func testNewGestureContinuesFromInterruptedAnimationOffset() {
        var session = InteractivePagingSession(
            currentPage: 1,
            pageCount: 4,
            pageStride: 1_000,
            startedAt: 0,
            initialOffset: -1_420
        )

        XCTAssertEqual(
            session.append(deltaX: 70, deltaY: 0, timestamp: 0.20),
            .tracking(offset: -1_350)
        )
        XCTAssertEqual(session.end(at: 0.30).targetPage, 1)
    }

    func testPointerGestureDoesNotUseFlickPrediction() {
        var session = InteractivePagingSession(
            currentPage: 1,
            pageCount: 4,
            pageStride: 1_000,
            startedAt: 0,
            allowsFlickPrediction: false
        )

        _ = session.append(deltaX: -80, deltaY: 0, timestamp: 0.02)

        XCTAssertEqual(session.end(at: 0.03).targetPage, 1)
    }

    func testSettleMotionMatchesAcrossSixtyAndOneHundredTwentyHertz() {
        let first120HzFrame = InteractivePagingSettleMotion.nextOffset(
            current: 0,
            target: 1_000,
            elapsed: 1.0 / 120.0
        )
        let second120HzFrame = InteractivePagingSettleMotion.nextOffset(
            current: first120HzFrame,
            target: 1_000,
            elapsed: 1.0 / 120.0
        )
        let one60HzFrame = InteractivePagingSettleMotion.nextOffset(
            current: 0,
            target: 1_000,
            elapsed: 1.0 / 60.0
        )

        XCTAssertEqual(first120HzFrame, 180, accuracy: 0.001)
        XCTAssertEqual(second120HzFrame, one60HzFrame, accuracy: 0.001)
    }

    private func makeSession(currentPage: Int, pageCount: Int = 4) -> InteractivePagingSession {
        InteractivePagingSession(
            currentPage: currentPage,
            pageCount: pageCount,
            pageStride: 1_000,
            startedAt: 0
        )
    }
}
