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

    func testUsesLocalizedInfoPlistStringsForDisplayName() throws {
        let appURL = try makeApplicationBundle(
            named: "Localized.app",
            bundleIdentifier: "com.example.Localized",
            displayName: "Raw Localized"
        )
        try writeLocalizedInfoPlistStrings(
            appURL: appURL,
            localization: "en",
            displayName: "Localized App"
        )

        let scanner = AppScanner(scanRoots: [temporaryDirectory])
        let apps = try scanner.scanApplications()

        XCTAssertEqual(apps[0].displayName, "Localized App")
    }

    func testUsesPreferredChineseLocalizationForDisplayName() throws {
        let appURL = try makeApplicationBundle(
            named: "ChineseLocalized.app",
            bundleIdentifier: "com.example.ChineseLocalized",
            displayName: "Raw Chinese Localized"
        )
        try writeLocalizedInfoPlistStrings(
            appURL: appURL,
            localization: "en",
            displayName: "English Localized App"
        )
        try writeLocalizedInfoPlistStrings(
            appURL: appURL,
            localization: "zh_CN",
            displayName: "中文应用"
        )

        let scanner = AppScanner(
            scanRoots: [temporaryDirectory],
            displayNameResolver: AppDisplayNameResolver(preferredLanguages: ["zh-Hans-CN"])
        )
        let apps = try scanner.scanApplications()

        XCTAssertEqual(apps[0].displayName, "中文应用")
    }

    func testUsesLocalizedInfoPlistLoctableForDisplayName() throws {
        let appURL = try makeApplicationBundle(
            named: "TableLocalized.app",
            bundleIdentifier: "com.example.TableLocalized",
            displayName: "Raw Table"
        )
        try writeLocalizedInfoPlistLoctable(
            appURL: appURL,
            localization: "en",
            displayName: "Localized Table App"
        )

        let scanner = AppScanner(scanRoots: [temporaryDirectory])
        let apps = try scanner.scanApplications()

        XCTAssertEqual(apps[0].displayName, "Localized Table App")
    }

    func testUsesSpotlightDisplayNameWhenItIsNotOnlyFileName() throws {
        try makeApplicationBundle(
            named: "SpotlightName.app",
            bundleIdentifier: "com.example.SpotlightName",
            displayName: "Raw Spotlight Name"
        )
        let metadataProvider = StubMetadataProvider(
            defaultMetadata: AppFileMetadata(
                spotlightDisplayName: "System Display Name",
                spotlightDateAdded: nil,
                creationDate: nil,
                modifiedDate: nil
            )
        )

        let scanner = AppScanner(scanRoots: [temporaryDirectory], metadataProvider: metadataProvider)
        let apps = try scanner.scanApplications()

        XCTAssertEqual(apps[0].displayName, "System Display Name")
    }

    func testKeepsRawNameAsSearchAliasAfterUsingLocalizedDisplayName() throws {
        let appURL = try makeApplicationBundle(
            named: "AliasLocalized.app",
            bundleIdentifier: "com.example.AliasLocalized",
            displayName: "Raw Alias Name"
        )
        try writeLocalizedInfoPlistStrings(
            appURL: appURL,
            localization: "en",
            displayName: "Localized Alias Name"
        )

        let scanner = AppScanner(scanRoots: [temporaryDirectory])
        let apps = try scanner.scanApplications()

        XCTAssertEqual(apps[0].displayName, "Localized Alias Name")
        XCTAssertTrue(apps[0].searchAliases.contains("Raw Alias Name"))
        XCTAssertTrue(apps[0].matchesSearchQuery("Raw Alias"))
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
        let cryptexApplications = URL(fileURLWithPath: "/System/Cryptexes/App/System/Applications", isDirectory: true)

        XCTAssertTrue(AppScanner.defaultScanRoots().contains(coreServicesApplications))
        XCTAssertTrue(AppScanner.defaultScanRoots().contains(cryptexApplications))
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

    func testCandidateVisibilityPolicyKeepsCryptexApplications() {
        let policy = AppCandidateVisibilityPolicy()

        XCTAssertTrue(policy.allows(URL(fileURLWithPath: "/System/Cryptexes/App/System/Applications/Safari.app")))
        XCTAssertTrue(policy.allows(URL(fileURLWithPath: "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app")))
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

    func testStoresResolvedPathForSymlinkedApplicationBundle() throws {
        let realDirectory = temporaryDirectory.appendingPathComponent("System/Cryptexes/App/System/Applications", isDirectory: true)
        try FileManager.default.createDirectory(at: realDirectory, withIntermediateDirectories: true)
        let realApp = try makeApplicationBundle(
            named: "Safari.app",
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            in: realDirectory
        )
        let applicationsDirectory = temporaryDirectory.appendingPathComponent("Applications", isDirectory: true)
        try FileManager.default.createDirectory(at: applicationsDirectory, withIntermediateDirectories: true)
        let symlinkApp = applicationsDirectory.appendingPathComponent("Safari.app", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: symlinkApp, withDestinationURL: realApp)

        let scanner = AppScanner(scanRoots: [applicationsDirectory], candidateProvider: StubCandidateProvider(urls: [symlinkApp]))
        let apps = try scanner.scanApplications()

        XCTAssertEqual(apps[0].path, realApp.resolvingSymlinksInPath().path)
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

    private func writeLocalizedInfoPlistStrings(
        appURL: URL,
        localization: String,
        displayName: String
    ) throws {
        let localizedDirectory = appURL
            .appendingPathComponent("Contents/Resources/\(localization).lproj", isDirectory: true)
        try FileManager.default.createDirectory(at: localizedDirectory, withIntermediateDirectories: true)

        let strings: [String: String] = [
            "CFBundleDisplayName": displayName,
            "CFBundleName": displayName
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: strings, format: .binary, options: 0)
        try data.write(to: localizedDirectory.appendingPathComponent("InfoPlist.strings"))
    }

    private func writeLocalizedInfoPlistLoctable(
        appURL: URL,
        localization: String,
        displayName: String
    ) throws {
        let resourcesDirectory = appURL.appendingPathComponent("Contents/Resources", isDirectory: true)
        try FileManager.default.createDirectory(at: resourcesDirectory, withIntermediateDirectories: true)

        let loctable: [String: [String: String]] = [
            localization: [
                "CFBundleDisplayName": displayName,
                "CFBundleName": displayName
            ]
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: loctable, format: .binary, options: 0)
        try data.write(to: resourcesDirectory.appendingPathComponent("InfoPlist.loctable"))
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
