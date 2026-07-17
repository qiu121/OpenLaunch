import AppKit
import XCTest
@testable import OpenLaunch

final class AppIconProviderTests: XCTestCase {
    @MainActor
    func testRepeatedIconRequestUsesCachedImage() {
        var loadCount = 0
        let sourceIcon = NSImage(size: NSSize(width: 32, height: 32))
        let provider = AppIconProvider { _ in
            loadCount += 1
            return sourceIcon
        }

        let firstIcon = provider.icon(for: "/Applications/Example.app", size: 96)
        let secondIcon = provider.icon(for: "/Applications/Example.app", size: 96)

        XCTAssertTrue(firstIcon === secondIcon)
        XCTAssertEqual(firstIcon.size, NSSize(width: 96, height: 96))
        XCTAssertEqual(loadCount, 1)
        XCTAssertEqual(sourceIcon.size, NSSize(width: 32, height: 32))
    }
}
