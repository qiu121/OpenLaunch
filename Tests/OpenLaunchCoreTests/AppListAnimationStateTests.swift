import XCTest
@testable import OpenLaunchCore

final class AppListAnimationStateTests: XCTestCase {
    func testRecordsAddedAppIDsForAutomaticRefresh() {
        var animationState = AppListAnimationState()
        let previousApps = [makeApp(id: "com.example.old", name: "Old")]
        let currentApps = previousApps + [makeApp(id: "com.example.new", name: "New")]

        animationState.recordAutomaticRefresh(previousApps: previousApps, currentApps: currentApps)

        XCTAssertEqual(animationState.pendingAnimatedAppIDs, Set(["com.example.new"]))
    }

    func testAutomaticRefreshKeepsPendingIDsUntilTheyAreConsumed() {
        var animationState = AppListAnimationState(pendingAnimatedAppIDs: ["com.example.new"])
        let currentApps = [
            makeApp(id: "com.example.old", name: "Old"),
            makeApp(id: "com.example.new", name: "New")
        ]

        animationState.recordAutomaticRefresh(previousApps: currentApps, currentApps: currentApps)

        XCTAssertEqual(animationState.pendingAnimatedAppIDs, Set(["com.example.new"]))
    }

    func testAutomaticRefreshDoesNotAnimateInitialEmptyStateScan() {
        var animationState = AppListAnimationState()
        let currentApps = [makeApp(id: "com.example.existing", name: "Existing")]

        animationState.recordAutomaticRefresh(previousApps: [], currentApps: currentApps)

        XCTAssertTrue(animationState.pendingAnimatedAppIDs.isEmpty)
    }

    func testManualRefreshDoesNotRecordAddedAppIDs() {
        var animationState = AppListAnimationState()
        let previousApps = [makeApp(id: "com.example.old", name: "Old")]
        let currentApps = previousApps + [makeApp(id: "com.example.new", name: "New")]

        animationState.recordManualRefresh(previousApps: previousApps, currentApps: currentApps)

        XCTAssertTrue(animationState.pendingAnimatedAppIDs.isEmpty)
    }

    func testConsumingPendingAnimatedAppIDsClearsState() {
        var animationState = AppListAnimationState(pendingAnimatedAppIDs: ["com.example.new"])

        XCTAssertEqual(animationState.consumePendingAnimatedAppIDs(), Set(["com.example.new"]))
        XCTAssertTrue(animationState.pendingAnimatedAppIDs.isEmpty)
    }

    private func makeApp(id: String, name: String) -> LaunchableApp {
        LaunchableApp(
            bundleIdentifier: id,
            path: "/Applications/\(name).app",
            displayName: name,
            addedDate: nil
        )
    }
}
