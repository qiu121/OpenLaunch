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

    func testLauncherBlankClickInterpreterKeepsInteractiveRegions() {
        let windowSize = CGSize(width: 1512, height: 982)
        let settings = OpenLaunchSettings.default
        let tileFrame = LaunchGridLayoutMetrics.tileHitFrame(for: 0, windowSize: windowSize, settings: settings)

        XCTAssertEqual(
            LauncherBlankClickInterpreter.action(
                at: CGPoint(x: tileFrame.midX, y: tileFrame.midY),
                windowSize: windowSize,
                settings: settings,
                displayedAppCount: 35
            ),
            .keepLauncher
        )
        XCTAssertEqual(
            LauncherBlankClickInterpreter.action(
                at: CGPoint(x: LaunchGridLayoutMetrics.searchHitFrame(windowSize: windowSize).midX, y: LaunchGridLayoutMetrics.searchHitFrame(windowSize: windowSize).midY),
                windowSize: windowSize,
                settings: settings,
                displayedAppCount: 35
            ),
            .keepLauncher
        )
        XCTAssertEqual(
            LauncherBlankClickInterpreter.action(
                at: CGPoint(x: LaunchGridLayoutMetrics.settingsHitFrame(windowSize: windowSize).midX, y: LaunchGridLayoutMetrics.settingsHitFrame(windowSize: windowSize).midY),
                windowSize: windowSize,
                settings: settings,
                displayedAppCount: 35
            ),
            .keepLauncher
        )
        XCTAssertEqual(
            LauncherBlankClickInterpreter.action(
                at: CGPoint(x: LaunchGridLayoutMetrics.footerHitFrame(windowSize: windowSize).midX, y: LaunchGridLayoutMetrics.footerHitFrame(windowSize: windowSize).midY),
                windowSize: windowSize,
                settings: settings,
                displayedAppCount: 35
            ),
            .keepLauncher
        )
    }

    func testLauncherBlankClickInterpreterHidesForBlankPagedArea() {
        XCTAssertEqual(
            LauncherBlankClickInterpreter.action(
                at: CGPoint(x: 36, y: 420),
                windowSize: CGSize(width: 1512, height: 982),
                settings: .default,
                displayedAppCount: 35
            ),
            .hideLauncher
        )
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

    func testScrollPagingIdleDelayAllowsSlowInteractiveScroll() {
        XCTAssertGreaterThanOrEqual(LaunchGridLayoutMetrics.scrollPagingIdleFinishDelayNanoseconds, 600_000_000)
    }

    func testLauncherChromePolicyKeepsContentBelowDockWithoutVisibleMenuBarShield() {
        XCTAssertLessThan(LauncherChromePolicy.contentWindowLevelRawValue, CGWindowLevelForKey(.dockWindow))
        XCTAssertFalse(LauncherChromePolicy.usesMenuBarShield)
    }

    func testLauncherChromePolicyDefersInitialPresentationForAccessoryLaunch() {
        XCTAssertGreaterThanOrEqual(LauncherChromePolicy.initialPresentationDelayNanoseconds, 180_000_000)
        XCTAssertTrue(LauncherChromePolicy.ordersWindowFrontRegardless)
        XCTAssertFalse(LauncherChromePolicy.hidesOnApplicationResignActive)
        XCTAssertFalse(LauncherChromePolicy.usesWindowAlphaFadeOnPresentation)
        XCTAssertTrue(LauncherChromePolicy.usesMainQueueForInitialPresentation)
        XCTAssertTrue(LauncherChromePolicy.requiresActiveApplicationForMenuBarHiding)
        XCTAssertTrue(LauncherChromePolicy.usesRegularActivationDuringPresentation)
        XCTAssertTrue(LauncherChromePolicy.usesAutoHideSystemBars)
        XCTAssertFalse(LauncherChromePolicy.usesForcedMenuBarHiding)
        XCTAssertTrue(LauncherChromePolicy.usesTransparentMenuBarTriggerShield)
        XCTAssertGreaterThanOrEqual(LauncherChromePolicy.menuBarTriggerShieldHeight, 44)
        XCTAssertTrue(LauncherChromePolicy.hidesStatusItemWhileLauncherVisible)
        XCTAssertFalse(LauncherChromePolicy.returnsToAccessoryImmediatelyAfterPresentation)
        XCTAssertTrue(LauncherChromePolicy.returnsToAccessoryAfterHiding)
        XCTAssertGreaterThanOrEqual(LauncherChromePolicy.externalActivationSuppressionAfterPresentationNanoseconds, 300_000_000)
    }

    func testSettingsMenuUsesCustomRowsWithMinimalSectionSeparators() {
        XCTAssertFalse(SettingsMenuPolicy.usesNativePickerSelection)
        XCTAssertTrue(SettingsMenuPolicy.showsSortGroupsInRootMenu)
        XCTAssertTrue(SettingsMenuPolicy.usesExplicitMenuSeparators)
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

    func testPageCarouselSnapTargetUsesDragDistance() {
        XCTAssertEqual(
            PageCarouselLayout.snapTargetPage(
                currentPage: 1,
                pageWidth: 1_000,
                translation: -210,
                predictedTranslation: -220,
                verticalTranslation: 20,
                pageCount: 4
            ),
            2
        )
        XCTAssertEqual(
            PageCarouselLayout.snapTargetPage(
                currentPage: 1,
                pageWidth: 1_000,
                translation: 210,
                predictedTranslation: 220,
                verticalTranslation: 20,
                pageCount: 4
            ),
            0
        )
    }

    func testPageCarouselSnapTargetUsesPredictedLightFlick() {
        XCTAssertEqual(
            PageCarouselLayout.snapTargetPage(
                currentPage: 1,
                pageWidth: 1_000,
                translation: -40,
                predictedTranslation: -190,
                verticalTranslation: 8,
                pageCount: 4
            ),
            2
        )
    }

    func testPageCarouselSnapTargetStaysOnCurrentPageForSmallOrVerticalDrags() {
        XCTAssertEqual(
            PageCarouselLayout.snapTargetPage(
                currentPage: 1,
                pageWidth: 1_000,
                translation: -80,
                predictedTranslation: -90,
                verticalTranslation: 12,
                pageCount: 4
            ),
            1
        )
        XCTAssertEqual(
            PageCarouselLayout.snapTargetPage(
                currentPage: 1,
                pageWidth: 1_000,
                translation: -280,
                predictedTranslation: -320,
                verticalTranslation: 310,
                pageCount: 4
            ),
            1
        )
    }

    func testPageCarouselSnapTargetUsesViewportProgressInsteadOfFixedDistanceCap() {
        XCTAssertEqual(
            PageCarouselLayout.snapTargetPage(
                currentPage: 1,
                pageWidth: 1_512,
                translation: -170,
                predictedTranslation: -180,
                verticalTranslation: 8,
                pageCount: 4
            ),
            1
        )
    }

    func testPageCarouselSnapTargetClampsAtEdges() {
        XCTAssertEqual(
            PageCarouselLayout.snapTargetPage(
                currentPage: 0,
                pageWidth: 1_000,
                translation: 260,
                predictedTranslation: 280,
                verticalTranslation: 10,
                pageCount: 4
            ),
            0
        )
        XCTAssertEqual(
            PageCarouselLayout.snapTargetPage(
                currentPage: 3,
                pageWidth: 1_000,
                translation: -260,
                predictedTranslation: -280,
                verticalTranslation: 10,
                pageCount: 4
            ),
            3
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

    func testStatusMenuPolicyKeepsRightClickMenuMinimal() {
        XCTAssertEqual(StatusMenuPolicy.items.map(\.title), ["重新扫描", "退出"])
        XCTAssertEqual(StatusMenuPolicy.items.map(\.action), [.rescanApplications, .quit])
    }

    func testSearchSessionPolicyResetsAndBlursWhenLauncherHides() {
        XCTAssertEqual(
            LauncherSearchSessionPolicy.actions(for: .didHide),
            [.resetSearchSession, .blurSearchField]
        )
    }

    func testSearchSessionPolicyBlursAgainAfterLauncherShows() {
        XCTAssertEqual(
            LauncherSearchSessionPolicy.actions(for: .didShow),
            [.blurSearchField, .deferredBlurSearchField]
        )
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

    func testRestorationPolicyDisablesSystemWindowRestoration() {
        XCTAssertFalse(LaunchWindowRestorationPolicy.supportsSecureRestorableState)
        XCTAssertFalse(LaunchWindowRestorationPolicy.quitAlwaysKeepsWindows)
    }
}
