import XCTest
@testable import OpenLaunchCore

final class LaunchableAppCodableTests: XCTestCase {
    func testDecodesLegacyPayloadWithoutSearchAliases() throws {
        let data = """
        {
          "bundleIdentifier": "com.example.Legacy",
          "path": "/Applications/Legacy.app",
          "displayName": "Legacy",
          "addedDate": null,
          "modifiedDate": null,
          "lastOpenedDate": null,
          "isHidden": false
        }
        """.data(using: .utf8)!

        let app = try JSONDecoder().decode(LaunchableApp.self, from: data)

        XCTAssertEqual(app.searchAliases, [])
    }
}
