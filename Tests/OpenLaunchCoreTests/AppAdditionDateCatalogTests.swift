import XCTest
@testable import OpenLaunchCore

final class AppAdditionDateCatalogTests: XCTestCase {
    func testInitialCatalogKeepsValidatedMetadataDates() {
        let oldDate = Date(timeIntervalSince1970: 100)
        let newDate = Date(timeIntervalSince1970: 200)
        let apps = [
            makeApp(id: "com.example.old", addedDate: oldDate),
            makeApp(id: "com.example.new", addedDate: newDate)
        ]
        var catalog = AppAdditionDateCatalog.uninitialized

        let resolvedApps = catalog.resolveAdditionDates(for: apps, detectedAt: Date(timeIntervalSince1970: 300))

        XCTAssertTrue(catalog.isInitialized)
        XCTAssertEqual(resolvedApps.map(\.addedDate), [oldDate, newDate])
        XCTAssertEqual(catalog.dates["com.example.old"], oldDate)
        XCTAssertEqual(catalog.dates["com.example.new"], newDate)
    }

    func testInitializedCatalogUsesDetectionDateForNewApplication() {
        let existingDate = Date(timeIntervalSince1970: 100)
        let detectionDate = Date(timeIntervalSince1970: 300)
        var catalog = AppAdditionDateCatalog(
            dates: ["com.example.existing": existingDate],
            isInitialized: true
        )
        let apps = [
            makeApp(id: "com.example.existing", addedDate: Date(timeIntervalSince1970: 250)),
            makeApp(id: "com.example.new", addedDate: Date(timeIntervalSince1970: 50))
        ]

        let resolvedApps = catalog.resolveAdditionDates(for: apps, detectedAt: detectionDate)

        XCTAssertEqual(resolvedApps[0].addedDate, existingDate)
        XCTAssertEqual(resolvedApps[1].addedDate, detectionDate)
        XCTAssertEqual(catalog.dates["com.example.new"], detectionDate)
    }

    func testExistingApplicationKeepsOriginalDateAfterBundleUpdate() {
        let originalDate = Date(timeIntervalSince1970: 100)
        var catalog = AppAdditionDateCatalog(
            dates: ["com.example.updated": originalDate],
            isInitialized: true
        )
        let updatedApp = makeApp(
            id: "com.example.updated",
            addedDate: Date(timeIntervalSince1970: 500)
        )

        let resolvedApps = catalog.resolveAdditionDates(
            for: [updatedApp],
            detectedAt: Date(timeIntervalSince1970: 600)
        )

        XCTAssertEqual(resolvedApps[0].addedDate, originalDate)
        XCTAssertEqual(catalog.dates["com.example.updated"], originalDate)
    }

    private func makeApp(id: String, addedDate: Date?) -> LaunchableApp {
        LaunchableApp(
            bundleIdentifier: id,
            path: "/Applications/\(id).app",
            displayName: id,
            addedDate: addedDate
        )
    }
}
