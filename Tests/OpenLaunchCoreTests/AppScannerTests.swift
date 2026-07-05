import XCTest
@testable import OpenLaunchCore

final class AppScannerTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenLaunchScannerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
    }

    func testScansApplicationBundleInfoPlist() throws {
        try makeApplicationBundle(
            named: "Example.app",
            bundleIdentifier: "com.example.Example",
            displayName: "Example App",
            category: "public.app-category.productivity"
        )

        let scanner = AppScanner(scanRoots: [temporaryDirectory])
        let apps = try scanner.scanApplications()

        XCTAssertEqual(apps.count, 1)
        XCTAssertEqual(apps[0].bundleIdentifier, "com.example.Example")
        XCTAssertEqual(apps[0].displayName, "Example App")
        XCTAssertEqual(apps[0].category, "public.app-category.productivity")
        XCTAssertNotNil(apps[0].addedDate)
    }

    func testUsesSpotlightDateAddedBeforeFileCreationDate() throws {
        try makeApplicationBundle(
            named: "NewlyAdded.app",
            bundleIdentifier: "com.example.NewlyAdded",
            displayName: "Newly Added"
        )
        let creationDate = Date(timeIntervalSince1970: 100)
        let spotlightDate = Date(timeIntervalSince1970: 500)
        let metadataProvider = StubMetadataProvider(
            defaultMetadata: AppFileMetadata(
                spotlightDateAdded: spotlightDate,
                creationDate: creationDate,
                modifiedDate: creationDate
            )
        )

        let scanner = AppScanner(scanRoots: [temporaryDirectory], metadataProvider: metadataProvider)
        let apps = try scanner.scanApplications()

        XCTAssertEqual(apps[0].addedDate, spotlightDate)
    }

    func testDefaultScanRootsIncludeCoreServicesApplications() {
        let coreServicesApplications = URL(fileURLWithPath: "/System/Library/CoreServices/Applications", isDirectory: true)

        XCTAssertTrue(AppScanner.defaultScanRoots().contains(coreServicesApplications))
    }

    func testScansApplicationsReturnedByCandidateProvider() throws {
        let indexedDirectory = temporaryDirectory.appendingPathComponent("Indexed", isDirectory: true)
        try FileManager.default.createDirectory(at: indexedDirectory, withIntermediateDirectories: true)
        let indexedApp = try makeApplicationBundle(
            named: "Indexed.app",
            bundleIdentifier: "com.example.Indexed",
            displayName: "Indexed",
            in: indexedDirectory
        )
        let provider = StubCandidateProvider(urls: [indexedApp, indexedApp])

        let scanner = AppScanner(
            scanRoots: [temporaryDirectory.appendingPathComponent("NotIndexed", isDirectory: true)],
            candidateProvider: provider
        )
        let apps = try scanner.scanApplications()

        XCTAssertEqual(apps.map(\.displayName), ["Indexed"])
    }

    func testCandidateVisibilityPolicyIncludesUserInstalledAppsOutsideApplications() {
        let policy = AppCandidateVisibilityPolicy()

        XCTAssertTrue(policy.allows(URL(fileURLWithPath: "/Users/geek/Downloads/Menu Bar Spacing.app")))
        XCTAssertTrue(policy.allows(URL(fileURLWithPath: "/Users/geek/Desktop/Tools/Example.app")))
    }

    func testCandidateVisibilityPolicyExcludesInternalSystemAndDaemonApps() {
        let policy = AppCandidateVisibilityPolicy()

        XCTAssertFalse(policy.allows(URL(fileURLWithPath: "/System/Library/CoreServices/Dock.app")))
        XCTAssertFalse(policy.allows(URL(fileURLWithPath: "/System/Library/PrivateFrameworks/CoreFollowUp.framework/Versions/A/Resources/FollowUpUI.app")))
        XCTAssertFalse(policy.allows(URL(fileURLWithPath: "/Users/geek/Library/Application Support/JetBrains/Daemon/bundles/current/jetbrainsd.app")))
    }

    func testCandidateVisibilityPolicyKeepsPublicCoreServicesApplications() {
        let policy = AppCandidateVisibilityPolicy()

        XCTAssertTrue(policy.allows(URL(fileURLWithPath: "/System/Library/CoreServices/Applications/Archive Utility.app")))
        XCTAssertTrue(policy.allows(URL(fileURLWithPath: "/System/Library/CoreServices/Applications/Keychain Access.app")))
    }

    func testFiltersBackgroundOnlyButKeepsAgentAppsWithUi() throws {
        try makeApplicationBundle(
            named: "Visible.app",
            bundleIdentifier: "com.example.Visible",
            displayName: "Visible"
        )
        try makeApplicationBundle(
            named: "Background.app",
            bundleIdentifier: "com.example.Background",
            displayName: "Background",
            extraInfo: ["LSBackgroundOnly": true]
        )
        try makeApplicationBundle(
            named: "Agent.app",
            bundleIdentifier: "com.example.Agent",
            displayName: "Agent",
            extraInfo: ["LSUIElement": true]
        )

        let scanner = AppScanner(scanRoots: [temporaryDirectory])
        let apps = try scanner.scanApplications()

        XCTAssertEqual(apps.map(\.displayName), ["Agent", "Visible"])
    }

    func testDeduplicatesByBundleIdentifier() throws {
        try makeApplicationBundle(
            named: "First.app",
            bundleIdentifier: "com.example.Shared",
            displayName: "First"
        )
        try makeApplicationBundle(
            named: "Second.app",
            bundleIdentifier: "com.example.Shared",
            displayName: "Second"
        )

        let scanner = AppScanner(scanRoots: [temporaryDirectory])
        let apps = try scanner.scanApplications()

        XCTAssertEqual(apps.count, 1)
        XCTAssertEqual(apps[0].bundleIdentifier, "com.example.Shared")
    }

    @discardableResult
    private func makeApplicationBundle(
        named name: String,
        bundleIdentifier: String,
        displayName: String,
        category: String? = nil,
        extraInfo: [String: Any] = [:],
        in directory: URL? = nil
    ) throws -> URL {
        let appURL = (directory ?? temporaryDirectory).appendingPathComponent(name, isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)

        var info: [String: Any] = [
            "CFBundleIdentifier": bundleIdentifier,
            "CFBundleDisplayName": displayName,
            "CFBundleName": displayName
        ]

        if let category {
            info["LSApplicationCategoryType"] = category
        }

        for (key, value) in extraInfo {
            info[key] = value
        }

        let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try data.write(to: contentsURL.appendingPathComponent("Info.plist"))
        return appURL
    }
}

private struct StubMetadataProvider: AppMetadataProviding {
    let defaultMetadata: AppFileMetadata

    func metadata(for appURL: URL) -> AppFileMetadata {
        defaultMetadata
    }
}

private struct StubCandidateProvider: AppCandidateProviding {
    let urls: [URL]

    func applicationURLs(in scanRoots: [URL]) -> [URL] {
        urls
    }
}
