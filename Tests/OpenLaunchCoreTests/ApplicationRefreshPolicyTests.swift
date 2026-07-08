import XCTest
@testable import OpenLaunchCore

final class ApplicationRefreshPolicyTests: XCTestCase {
    func testDirectoryChangeWhileHiddenMarksRefreshForNextPresentation() {
        var policy = ApplicationRefreshPolicy()

        let changeAction = policy.handleApplicationDirectoryChange(isLauncherVisible: false)

        XCTAssertEqual(changeAction, .markNeedsRefresh)
        XCTAssertTrue(policy.needsRefresh)
        XCTAssertEqual(policy.handleLauncherWillShow(), .rescanImmediately)
        XCTAssertFalse(policy.needsRefresh)
        XCTAssertEqual(policy.handleLauncherWillShow(), .noAction)
    }

    func testDirectoryChangeWhileVisibleRequestsImmediateRescan() {
        var policy = ApplicationRefreshPolicy()

        let changeAction = policy.handleApplicationDirectoryChange(isLauncherVisible: true)

        XCTAssertEqual(changeAction, .rescanImmediately)
        XCTAssertFalse(policy.needsRefresh)
        XCTAssertEqual(policy.handleLauncherWillShow(), .noAction)
    }

    func testManualRescanClearsPendingRefresh() {
        var policy = ApplicationRefreshPolicy()
        _ = policy.handleApplicationDirectoryChange(isLauncherVisible: false)

        XCTAssertEqual(policy.handleManualRescan(), .rescanImmediately)
        XCTAssertFalse(policy.needsRefresh)
        XCTAssertEqual(policy.handleLauncherWillShow(), .noAction)
    }
}
