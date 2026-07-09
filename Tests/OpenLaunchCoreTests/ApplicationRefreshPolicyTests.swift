import XCTest
@testable import OpenLaunchCore

final class ApplicationRefreshPolicyTests: XCTestCase {
    func testDirectoryChangeWhileHiddenRequestsImmediateBackgroundRescan() {
        var policy = ApplicationRefreshPolicy()

        let changeAction = policy.handleApplicationDirectoryChange(isLauncherVisible: false)

        XCTAssertEqual(changeAction, .rescanImmediately)
        XCTAssertEqual(policy.handleLauncherWillShow(), .noAction)
    }

    func testDirectoryChangeWhileVisibleRequestsImmediateRescan() {
        var policy = ApplicationRefreshPolicy()

        let changeAction = policy.handleApplicationDirectoryChange(isLauncherVisible: true)

        XCTAssertEqual(changeAction, .rescanImmediately)
        XCTAssertEqual(policy.handleLauncherWillShow(), .noAction)
    }

    func testManualRescanRequestsImmediateRescan() {
        var policy = ApplicationRefreshPolicy()
        _ = policy.handleApplicationDirectoryChange(isLauncherVisible: false)

        XCTAssertEqual(policy.handleManualRescan(), .rescanImmediately)
        XCTAssertEqual(policy.handleLauncherWillShow(), .noAction)
    }
}
