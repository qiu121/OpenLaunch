import XCTest
@testable import OpenLaunchCore

final class AppListChangeSummaryTests: XCTestCase {
    func testAddedAppIDsReturnsOnlyAppsMissingFromPreviousList() {
        let previousApps = [
            makeApp(id: "com.example.existing", name: "Existing"),
            makeApp(id: "com.example.removed", name: "Removed")
        ]
        let currentApps = [
            makeApp(id: "com.example.existing", name: "Existing"),
            makeApp(id: "com.example.added", name: "Added")
        ]

        let addedAppIDs = AppListChangeSummary.addedAppIDs(
            previousApps: previousApps,
            currentApps: currentApps
        )

        XCTAssertEqual(addedAppIDs, ["com.example.added"])
    }

    func testAddedAppIDsLimitsHighlightedApps() {
        let currentApps = (0..<8).map { index in
            makeApp(id: "com.example.added.\(index)", name: "Added \(index)")
        }

        let addedAppIDs = AppListChangeSummary.addedAppIDs(
            previousApps: [],
            currentApps: currentApps,
            limit: 6
        )

        XCTAssertEqual(
            addedAppIDs,
            (0..<6).map { "com.example.added.\($0)" }
        )
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
