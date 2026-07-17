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

    func testPagingIdleFallbackDoesNotDelayReleaseFeedback() {
        XCTAssertGreaterThanOrEqual(LaunchGridLayoutMetrics.pageGestureIdleFinishDelay, 0.08)
        XCTAssertLessThanOrEqual(LaunchGridLayoutMetrics.pageGestureIdleFinishDelay, 0.20)
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
