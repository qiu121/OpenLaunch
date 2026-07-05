import XCTest
@testable import OpenLaunchCore

final class SettingsStoreTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenLaunchSettingsStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
    }

    func testMissingSettingsReturnDefaultAddedDateSort() throws {
        let store = SettingsStore(applicationSupportDirectory: temporaryDirectory)

        let settings = try store.loadSettings()

        XCTAssertEqual(settings.sortMode, .addedDate)
        XCTAssertEqual(settings.displayMode, .paged)
        XCTAssertTrue(settings.showLabels)
    }

    func testSavedSettingsRoundTrip() throws {
        let store = SettingsStore(applicationSupportDirectory: temporaryDirectory)
        let expected = OpenLaunchSettings(
            sortMode: .custom,
            displayMode: .scroll,
            gridDensity: .small,
            showLabels: false,
            hotkey: Hotkey(keyCode: 37, modifiers: 1_572_864),
            customOrder: [
                "com.example.B": 0,
                "com.example.A": 1
            ]
        )

        try store.saveSettings(expected)
        let loaded = try store.loadSettings()

        XCTAssertEqual(loaded, expected)
    }

    func testRecentOpenDatesRoundTrip() throws {
        let store = SettingsStore(applicationSupportDirectory: temporaryDirectory)
        let recents = [
            "com.example.one": Date(timeIntervalSince1970: 100),
            "com.example.two": Date(timeIntervalSince1970: 200)
        ]

        try store.saveRecentOpenDates(recents)
        let loaded = try store.loadRecentOpenDates()

        XCTAssertEqual(loaded, recents)
    }
}
