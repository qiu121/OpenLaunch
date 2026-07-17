import XCTest
@testable import OpenLaunchCore

final class AppSorterTests: XCTestCase {
    func testDefaultSettingsSortByAddedDateOldestFirst() {
        let oldDate = Date(timeIntervalSince1970: 100)
        let newDate = Date(timeIntervalSince1970: 300)
        let middleDate = Date(timeIntervalSince1970: 200)

        let apps = [
            LaunchableApp(bundleIdentifier: "com.example.old", path: "/Applications/Old.app", displayName: "Old", addedDate: oldDate),
            LaunchableApp(bundleIdentifier: "com.example.new", path: "/Applications/New.app", displayName: "New", addedDate: newDate),
            LaunchableApp(bundleIdentifier: "com.example.middle", path: "/Applications/Middle.app", displayName: "Middle", addedDate: middleDate)
        ]

        let sorted = AppSorter.sorted(apps, using: OpenLaunchSettings.default)

        XCTAssertEqual(sorted.map(\.displayName), ["Old", "Middle", "New"])
    }

    func testNameSortUsesLocalizedAscendingOrder() {
        let apps = [
            LaunchableApp(bundleIdentifier: "com.example.safari", path: "/Applications/Safari.app", displayName: "Safari", addedDate: nil),
            LaunchableApp(bundleIdentifier: "com.example.arc", path: "/Applications/Arc.app", displayName: "Arc", addedDate: nil),
            LaunchableApp(bundleIdentifier: "com.example.notes", path: "/Applications/Notes.app", displayName: "Notes", addedDate: nil)
        ]

        let settings = OpenLaunchSettings(sortMode: .name, displayMode: .paged, gridDensity: .medium, showLabels: true, hotkey: nil)
        let sorted = AppSorter.sorted(apps, using: settings)

        XCTAssertEqual(sorted.map(\.displayName), ["Arc", "Notes", "Safari"])
    }

    func testAddedDateSortCanUseNewestFirstDirection() {
        let oldDate = Date(timeIntervalSince1970: 100)
        let newDate = Date(timeIntervalSince1970: 300)
        let middleDate = Date(timeIntervalSince1970: 200)
        let apps = [
            LaunchableApp(bundleIdentifier: "com.example.old", path: "/Applications/Old.app", displayName: "Old", addedDate: oldDate),
            LaunchableApp(bundleIdentifier: "com.example.new", path: "/Applications/New.app", displayName: "New", addedDate: newDate),
            LaunchableApp(bundleIdentifier: "com.example.middle", path: "/Applications/Middle.app", displayName: "Middle", addedDate: middleDate)
        ]

        let settings = OpenLaunchSettings(
            sortMode: .addedDate,
            sortDirection: .reverse,
            displayMode: .paged,
            gridDensity: .medium,
            showLabels: true,
            hotkey: nil
        )
        let sorted = AppSorter.sorted(apps, using: settings)

        XCTAssertEqual(sorted.map(\.displayName), ["New", "Middle", "Old"])
    }

    func testNewestFirstAddedDateSortKeepsUnknownDatesLast() {
        let knownDate = Date(timeIntervalSince1970: 100)
        let apps = [
            LaunchableApp(bundleIdentifier: "com.example.unknown", path: "/Applications/Unknown.app", displayName: "Unknown", addedDate: nil),
            LaunchableApp(bundleIdentifier: "com.example.known", path: "/Applications/Known.app", displayName: "Known", addedDate: knownDate)
        ]
        let settings = OpenLaunchSettings(
            sortMode: .addedDate,
            sortDirection: .reverse,
            displayMode: .paged,
            gridDensity: .medium,
            showLabels: true,
            hotkey: nil
        )

        let sorted = AppSorter.sorted(apps, using: settings)

        XCTAssertEqual(sorted.map(\.displayName), ["Known", "Unknown"])
    }

    func testAddedDateTiesKeepNameOrderInBothDirections() {
        let sameDate = Date(timeIntervalSince1970: 100)
        let apps = [
            LaunchableApp(bundleIdentifier: "com.example.zed", path: "/Applications/Zed.app", displayName: "Zed", addedDate: sameDate),
            LaunchableApp(bundleIdentifier: "com.example.arc", path: "/Applications/Arc.app", displayName: "Arc", addedDate: sameDate)
        ]
        let reverseSettings = OpenLaunchSettings(
            sortMode: .addedDate,
            sortDirection: .reverse,
            displayMode: .paged,
            gridDensity: .medium,
            showLabels: true,
            hotkey: nil
        )

        let forward = AppSorter.sorted(apps, using: .default)
        let reverse = AppSorter.sorted(apps, using: reverseSettings)

        XCTAssertEqual(forward.map(\.displayName), ["Arc", "Zed"])
        XCTAssertEqual(reverse.map(\.displayName), ["Arc", "Zed"])
    }

    func testNameSortCanUseReverseDirection() {
        let apps = [
            LaunchableApp(bundleIdentifier: "com.example.safari", path: "/Applications/Safari.app", displayName: "Safari", addedDate: nil),
            LaunchableApp(bundleIdentifier: "com.example.arc", path: "/Applications/Arc.app", displayName: "Arc", addedDate: nil),
            LaunchableApp(bundleIdentifier: "com.example.notes", path: "/Applications/Notes.app", displayName: "Notes", addedDate: nil)
        ]

        let settings = OpenLaunchSettings(
            sortMode: .name,
            sortDirection: .reverse,
            displayMode: .paged,
            gridDensity: .medium,
            showLabels: true,
            hotkey: nil
        )
        let sorted = AppSorter.sorted(apps, using: settings)

        XCTAssertEqual(sorted.map(\.displayName), ["Safari", "Notes", "Arc"])
    }

    func testCustomSortIgnoresSortDirection() {
        let apps = [
            LaunchableApp(bundleIdentifier: "com.example.alpha", path: "/Applications/Alpha.app", displayName: "Alpha", addedDate: nil),
            LaunchableApp(bundleIdentifier: "com.example.beta", path: "/Applications/Beta.app", displayName: "Beta", addedDate: nil)
        ]

        let settings = OpenLaunchSettings(
            sortMode: .custom,
            sortDirection: .reverse,
            displayMode: .paged,
            gridDensity: .medium,
            showLabels: true,
            hotkey: nil,
            customOrder: [
                "com.example.alpha": 0,
                "com.example.beta": 1
            ]
        )
        let sorted = AppSorter.sorted(apps, using: settings)

        XCTAssertEqual(sorted.map(\.displayName), ["Alpha", "Beta"])
    }

    func testRecentlyOpenedSortFallsBackToNameWhenNoRecentDateExists() {
        let apps = [
            LaunchableApp(bundleIdentifier: "com.example.zed", path: "/Applications/Zed.app", displayName: "Zed", addedDate: nil, lastOpenedDate: nil),
            LaunchableApp(bundleIdentifier: "com.example.arc", path: "/Applications/Arc.app", displayName: "Arc", addedDate: nil, lastOpenedDate: nil)
        ]

        let settings = OpenLaunchSettings(sortMode: .lastOpened, displayMode: .paged, gridDensity: .medium, showLabels: true, hotkey: nil)
        let sorted = AppSorter.sorted(apps, using: settings)

        XCTAssertEqual(sorted.map(\.displayName), ["Arc", "Zed"])
    }

    func testRecentlyOpenedSortPlacesNewestOpenedAppLast() {
        let oldOpenDate = Date(timeIntervalSince1970: 100)
        let newOpenDate = Date(timeIntervalSince1970: 300)
        let apps = [
            LaunchableApp(bundleIdentifier: "com.example.never", path: "/Applications/Never.app", displayName: "Never", addedDate: nil, lastOpenedDate: nil),
            LaunchableApp(bundleIdentifier: "com.example.old", path: "/Applications/Old.app", displayName: "Old", addedDate: nil, lastOpenedDate: oldOpenDate),
            LaunchableApp(bundleIdentifier: "com.example.new", path: "/Applications/New.app", displayName: "New", addedDate: nil, lastOpenedDate: newOpenDate)
        ]

        let settings = OpenLaunchSettings(sortMode: .lastOpened, displayMode: .paged, gridDensity: .medium, showLabels: true, hotkey: nil)
        let sorted = AppSorter.sorted(apps, using: settings)

        XCTAssertEqual(sorted.map(\.displayName), ["Never", "Old", "New"])
    }

    func testRecentlyOpenedSortCanUseNewestFirstDirection() {
        let oldOpenDate = Date(timeIntervalSince1970: 100)
        let newOpenDate = Date(timeIntervalSince1970: 300)
        let apps = [
            LaunchableApp(bundleIdentifier: "com.example.never", path: "/Applications/Never.app", displayName: "Never", addedDate: nil, lastOpenedDate: nil),
            LaunchableApp(bundleIdentifier: "com.example.old", path: "/Applications/Old.app", displayName: "Old", addedDate: nil, lastOpenedDate: oldOpenDate),
            LaunchableApp(bundleIdentifier: "com.example.new", path: "/Applications/New.app", displayName: "New", addedDate: nil, lastOpenedDate: newOpenDate)
        ]

        let settings = OpenLaunchSettings(
            sortMode: .lastOpened,
            sortDirection: .reverse,
            displayMode: .paged,
            gridDensity: .medium,
            showLabels: true,
            hotkey: nil
        )
        let sorted = AppSorter.sorted(apps, using: settings)

        XCTAssertEqual(sorted.map(\.displayName), ["New", "Old", "Never"])
    }
}
