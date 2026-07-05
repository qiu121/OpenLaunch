import CoreGraphics
import XCTest
@testable import OpenLaunchCore

final class LaunchGridLayoutMetricsTests: XCTestCase {
    func testDefaultGridMetricsKeepSevenByFiveWithLargerIcons() {
        XCTAssertEqual(OpenLaunchSettings.default.gridDensity.columns, 7)
        XCTAssertEqual(OpenLaunchSettings.default.gridDensity.rows, 5)
        XCTAssertEqual(LaunchGridLayoutMetrics.iconSize, 96)
        XCTAssertEqual(LaunchGridLayoutMetrics.tileWidth, 146)
        XCTAssertEqual(LaunchGridLayoutMetrics.labeledTileHeight, 146)
    }

    func testDefaultSevenByFiveGridStillFitsReferenceDisplay() {
        let lastTileFrame = LaunchGridLayoutMetrics.tileHitFrame(
            for: 34,
            windowSize: CGSize(width: 1512, height: 982),
            settings: .default
        )

        XCTAssertLessThanOrEqual(lastTileFrame.maxY, 982)
    }

    func testSearchHitFrameSitsAwayFromTopEdge() {
        let frame = LaunchGridLayoutMetrics.searchHitFrame(windowSize: CGSize(width: 1512, height: 982))

        XCTAssertGreaterThanOrEqual(frame.minY, 40)
        XCTAssertEqual(frame.width, 420)
        XCTAssertEqual(LaunchGridLayoutMetrics.searchControlHeight, 44)
        XCTAssertEqual(LaunchGridLayoutMetrics.searchTextFieldHeight, 22)
    }

    func testHorizontalSwipeDirectionIgnoresVerticalMovement() {
        XCTAssertEqual(PageSwipeInterpreter.direction(deltaX: -18, deltaY: 4), .next)
        XCTAssertEqual(PageSwipeInterpreter.direction(deltaX: 18, deltaY: 4), .previous)
        XCTAssertNil(PageSwipeInterpreter.direction(deltaX: 18, deltaY: 40))
    }

    func testScrollAccumulatorTurnsSmallHorizontalDeltasIntoOnePageTurn() {
        var accumulator = PageSwipeAccumulator(threshold: 24)

        XCTAssertNil(accumulator.append(deltaX: -8, deltaY: 1))
        XCTAssertNil(accumulator.append(deltaX: -8, deltaY: 1))
        XCTAssertEqual(accumulator.append(deltaX: -8, deltaY: 1), .next)
        XCTAssertNil(accumulator.append(deltaX: -8, deltaY: 1))
    }

    func testScrollAccumulatorResetsWhenVerticalMovementDominates() {
        var accumulator = PageSwipeAccumulator(threshold: 24)

        XCTAssertNil(accumulator.append(deltaX: -8, deltaY: 18))
        XCTAssertNil(accumulator.append(deltaX: -8, deltaY: 18))
        XCTAssertNil(accumulator.append(deltaX: -8, deltaY: 1))
    }

    func testPageCarouselOffsetMovesWholePageTrackContinuously() {
        XCTAssertEqual(
            PageCarouselLayout.offset(currentPage: 2, pageWidth: 1_000, dragTranslation: -120, pageCount: 4),
            -2_120
        )
    }

    func testPageCarouselOffsetAppliesResistanceAtEdges() {
        XCTAssertEqual(
            PageCarouselLayout.offset(currentPage: 0, pageWidth: 1_000, dragTranslation: 100, pageCount: 4),
            24
        )
        XCTAssertEqual(
            PageCarouselLayout.offset(currentPage: 3, pageWidth: 1_000, dragTranslation: -100, pageCount: 4),
            -3_024
        )
    }

    func testPageCarouselTargetDirectionUsesPredictedDrag() {
        XCTAssertEqual(
            PageCarouselLayout.targetDirection(translation: -18, predictedTranslation: -170, verticalTranslation: 4),
            .next
        )
        XCTAssertNil(
            PageCarouselLayout.targetDirection(translation: -18, predictedTranslation: -30, verticalTranslation: 4)
        )
    }

    func testDockRevealInsetLeavesAUsableTriggerBand() {
        XCTAssertGreaterThanOrEqual(LaunchGridLayoutMetrics.dockRevealInset, 24)
    }

    func testStatusItemPrimaryClickShowsLauncher() {
        XCTAssertEqual(StatusItemClickInterpreter.action(isSecondaryClick: false, isControlPressed: false), .showLauncher)
        XCTAssertEqual(StatusItemClickInterpreter.action(isSecondaryClick: true, isControlPressed: false), .showMenu)
        XCTAssertEqual(StatusItemClickInterpreter.action(isSecondaryClick: false, isControlPressed: true), .showMenu)
    }

    func testRestorationPolicyFindsSwiftUISavedLauncherFrameKeys() {
        let keys = [
            "AppleLanguages",
            "NSWindow Frame SwiftUI.ModifiedContent<OpenLaunch.ContentView, SwiftUI._AppearanceActionModifier>-1-AppWindow-1",
            "NSWindow Frame SomeOtherWindow"
        ]

        XCTAssertEqual(
            LaunchWindowRestorationPolicy.staleWindowFrameKeys(in: keys),
            ["NSWindow Frame SwiftUI.ModifiedContent<OpenLaunch.ContentView, SwiftUI._AppearanceActionModifier>-1-AppWindow-1"]
        )
    }
}
