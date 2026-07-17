import AppKit
import XCTest
@testable import OpenLaunch

final class PagingScrollInputTests: XCTestCase {
    func testUsesDominantAxisAndLaunchpadTrackingGain() {
        XCTAssertEqual(PagingScrollInput.trackingDelta(horizontal: -24, vertical: 3), -48)
        XCTAssertEqual(PagingScrollInput.trackingDelta(horizontal: -3, vertical: -18), -36)
        XCTAssertEqual(PagingScrollInput.trackingDelta(horizontal: 8, vertical: 8), 16)
    }

    func testTracksTheFirstGestureDeltaAndStopsAtTheEnd() {
        XCTAssertTrue(PagingScrollInput.tracksDelta(during: .began))
        XCTAssertTrue(PagingScrollInput.tracksDelta(during: .changed))
        XCTAssertTrue(PagingScrollInput.tracksDelta(during: []))
        XCTAssertFalse(PagingScrollInput.tracksDelta(during: .ended))
        XCTAssertFalse(PagingScrollInput.tracksDelta(during: .cancelled))
    }
}
