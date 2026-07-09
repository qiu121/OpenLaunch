import Foundation
import CoreServices

/// 扫描本机 `.app` bundle 并转换为 OpenLaunch 可展示的应用记录。
public struct AppScanner {
    /// 需要扫描的根目录。
    public let scanRoots: [URL]
    private let excludedBundleIdentifiers: Set<String>
    private let excludedApplicationPaths: Set<String>

    private let metadataProvider: any AppMetadataProviding
    private let candidateProvider: any AppCandidateProviding
    private let displayNameResolver: AppDisplayNameResolver

    public init(
        scanRoots: [URL] = AppScanner.defaultScanRoots(),
        metadataProvider: any AppMetadataProviding = SpotlightMetadataProvider(),
        candidateProvider: (any AppCandidateProviding)? = nil,
        displayNameResolver: AppDisplayNameResolver = AppDisplayNameResolver(),
        excludedBundleIdentifiers: Set<String> = AppScanner.defaultExcludedBundleIdentifiers(),
        excludedApplicationPaths: Set<String> = AppScanner.defaultExcludedApplicationPaths()
    ) {
        self.scanRoots = scanRoots
        self.excludedBundleIdentifiers = excludedBundleIdentifiers
        self.excludedApplicationPaths = excludedApplicationPaths
        self.metadataProvider = metadataProvider
        self.candidateProvider = candidateProvider ?? AppScanner.defaultCandidateProvider(for: scanRoots)
        self.displayNameResolver = displayNameResolver
    }

    /// 扫描所有根目录，返回已过滤、去重后的应用列表。
    public func scanApplications() throws -> [LaunchableApp] {
        var apps: [LaunchableApp] = []
        var seenKeys = Set<String>()

        for appURL in candidateProvider.applicationURLs(in: scanRoots) {
            if let app = try application(at: appURL), seenKeys.insert(app.stableKey).inserted {
                apps.append(app)
            }
        }

        let nameSortSettings = OpenLaunchSettings(
            sortMode: .name,
            displayMode: .paged,
            gridDensity: .medium,
            showLabels: true,
            hotkey: nil
        )

        return AppSorter.sorted(apps, using: nameSortSettings)
    }

    private func application(at appURL: URL) throws -> LaunchableApp? {
        let resolvedAppURL = appURL.standardizedFileURL.resolvingSymlinksInPath()
        let infoURL = resolvedAppURL.appendingPathComponent("Contents/Info.plist")
        let info = try readInfoPlist(at: infoURL)
        let bundleIdentifier = stringValue(info["CFBundleIdentifier"])

        if isExcludedSelfApplication(at: resolvedAppURL, bundleIdentifier: bundleIdentifier) {
            return nil
        }

        if boolValue(info["LSBackgroundOnly"]) {
            return nil
        }

        let category = stringValue(info["LSApplicationCategoryType"])
        let metadata = metadataProvider.metadata(for: resolvedAppURL)
        let nameResolution = displayNameResolver.resolveDisplayName(
            for: resolvedAppURL,
            info: info,
            metadata: metadata
        )
        let modifiedDate = metadata.modifiedDate
        let addedDate = metadata.spotlightDateAdded ?? metadata.creationDate ?? metadata.modifiedDate

        return LaunchableApp(
            bundleIdentifier: bundleIdentifier,
            path: resolvedAppURL.path,
            displayName: nameResolution.displayName,
            searchAliases: nameResolution.searchAliases,
            category: category,
            addedDate: addedDate,
            modifiedDate: modifiedDate
        )
    }

    private func isExcludedSelfApplication(at appURL: URL, bundleIdentifier: String?) -> Bool {
        if let bundleIdentifier, excludedBundleIdentifiers.contains(bundleIdentifier) {
            return true
        }

        let appPath = appURL.standardizedFileURL.resolvingSymlinksInPath().path
        let normalizedAppPath = normalizedPath(appPath)

        if excludedApplicationPaths.contains(appPath) || excludedApplicationPaths.contains(normalizedAppPath) {
            return true
        }

        return excludedApplicationPaths.contains(appPath.lowercased()) || excludedApplicationPaths.contains(normalizedAppPath.lowercased())
    }

    private func normalizedPath(_ path: String) -> String {
        if path.hasPrefix("/private/") {
            return String(path.dropFirst("/private/".count))
        }

        return path
    }

    private func readInfoPlist(at url: URL) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return [:]
        }

        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return plist as? [String: Any] ?? [:]
    }

    private func stringValue(_ value: Any?) -> String? {
        guard let value else {
            return nil
        }

        if let string = value as? String, !string.isEmpty {
            return string
        }

        return nil
    }

    private func boolValue(_ value: Any?) -> Bool {
        switch value {
        case let bool as Bool:
            return bool
        case let number as NSNumber:
            return number.boolValue
        case let string as String:
            return ["1", "true", "yes"].contains(string.lowercased())
        default:
            return false
        }
    }

    /// OpenLaunch 默认扫描的应用目录。
    public static func defaultScanRoots() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser

        return [
            URL(fileURLWithPath: "/System/Cryptexes/App/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/Applications/Utilities", isDirectory: true),
            URL(fileURLWithPath: "/System/Library/CoreServices/Applications", isDirectory: true),
            home.appendingPathComponent("Applications", isDirectory: true)
        ]
    }

    public static func defaultExcludedBundleIdentifiers() -> Set<String> {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return []
        }

        return [bundleIdentifier]
    }

    public static func defaultExcludedApplicationPaths() -> Set<String> {
        let bundlePath = Bundle.main.bundleURL.standardizedFileURL.resolvingSymlinksInPath().path
        return [bundlePath]
    }

    private static func defaultCandidateProvider(for scanRoots: [URL]) -> any AppCandidateProviding {
        if scanRoots == defaultScanRoots() {
            return MergedAppCandidateProvider(providers: [
                SpotlightAppCandidateProvider(restrictToScanRoots: false),
                FileSystemAppCandidateProvider()
            ])
        }

        return FileSystemAppCandidateProvider()
    }
}

/// 提供待解析的 `.app` URL；扫描器仍负责读取 Info.plist 和过滤后台应用。
public protocol AppCandidateProviding {
    func applicationURLs(in scanRoots: [URL]) -> [URL]
}

/// 基于文件系统递归枚举 `.app` bundle，作为 Spotlight 不可用时的稳定兜底。
public struct FileSystemAppCandidateProvider: AppCandidateProviding {
    public init() {}

    public func applicationURLs(in scanRoots: [URL]) -> [URL] {
        var urls: [URL] = []

        for root in scanRoots {
            guard FileManager.default.fileExists(atPath: root.path) else {
                continue
            }

            if root.isApplicationBundle {
                urls.append(root)
                continue
            }

            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            for case let url as URL in enumerator {
                guard url.isApplicationBundle else {
                    continue
                }

                enumerator.skipDescendants()
                urls.append(url)
            }
        }

        return urls
    }
}

/// 基于 Spotlight 索引获取应用 bundle，补齐文件枚举不容易覆盖的系统公开应用。
public struct SpotlightAppCandidateProvider: AppCandidateProviding {
    private let visibilityPolicy: AppCandidateVisibilityPolicy
    private let restrictToScanRoots: Bool

    public init(
        visibilityPolicy: AppCandidateVisibilityPolicy = AppCandidateVisibilityPolicy(),
        restrictToScanRoots: Bool = true
    ) {
        self.visibilityPolicy = visibilityPolicy
        self.restrictToScanRoots = restrictToScanRoots
    }

    public func applicationURLs(in scanRoots: [URL]) -> [URL] {
        let queryText: CFString = "kMDItemContentTypeTree == \"com.apple.application-bundle\"" as CFString
        guard let query = MDQueryCreate(kCFAllocatorDefault, queryText, nil, nil),
              MDQueryExecute(query, CFOptionFlags(kMDQuerySynchronous.rawValue)) else {
            return []
        }
        defer {
            MDQueryStop(query)
        }

        let rootPaths = scanRoots.map(\.standardizedDirectoryPath)
        let count = MDQueryGetResultCount(query)
        var urls: [URL] = []

        for index in 0..<count {
            guard let rawItem = MDQueryGetResultAtIndex(query, index) else {
                continue
            }

            let item = unsafeBitCast(rawItem, to: MDItem.self)
            guard let path = MDItemCopyAttribute(item, kMDItemPath) as? String else {
                continue
            }

            let url = URL(fileURLWithPath: path, isDirectory: true)
            guard url.isApplicationBundle,
                  visibilityPolicy.allows(url),
                  (!restrictToScanRoots || url.isContained(inAnyDirectoryPath: rootPaths)) else {
                continue
            }

            urls.append(url)
        }

        return urls
    }
}

/// 判断 Spotlight 中的 `.app` 是否应作为用户可见应用候选。
public struct AppCandidateVisibilityPolicy {
    private let homeDirectory: URL

    public init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeDirectory = homeDirectory
    }

    public func allows(_ appURL: URL) -> Bool {
        let path = appURL.standardizedFileURL.path
        guard appURL.isApplicationBundle else {
            return false
        }

        if path.contains(".app/Contents/") {
            return false
        }

        if isPublicApplicationPath(path) {
            return true
        }

        if isKnownInternalPath(path) {
            return false
        }

        return isUserOwnedStandaloneApplication(path) || isSharedSupportApplication(path)
    }

    private func isPublicApplicationPath(_ path: String) -> Bool {
        let publicRoots = [
            "/Applications",
            "/System/Applications",
            "/System/Cryptexes/App/System/Applications",
            "/System/Volumes/Preboot/Cryptexes/App/System/Applications",
            "/System/Library/CoreServices/Applications",
            homeDirectory.appendingPathComponent("Applications", isDirectory: true).standardizedDirectoryPath
        ]

        return publicRoots.contains { rootPath in
            path == rootPath || path.hasPrefix(rootPath + "/")
        }
    }

    private func isKnownInternalPath(_ path: String) -> Bool {
        let exactInternalPrefixes = [
            "/System/Library/CoreServices",
            "/System/Library/Frameworks",
            "/System/Library/PrivateFrameworks",
            "/Library/Apple/System/Library",
            "/Library/Developer/CommandLineTools"
        ]

        if exactInternalPrefixes.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) {
            return true
        }

        let internalFragments = [
            "/Library/Application Support/Script Editor/Templates/",
            "/Library/Application Support/JetBrains/Daemon/",
            "/Library/Application Support/Google/GoogleUpdater/",
            "/Library/Application Support/apifox/ApifoxAppAgent.app",
            "/autoupdate/"
        ]

        return internalFragments.contains { path.contains($0) }
    }

    private func isUserOwnedStandaloneApplication(_ path: String) -> Bool {
        let homePath = homeDirectory.standardizedDirectoryPath
        guard path.hasPrefix(homePath + "/") else {
            return false
        }

        let userLibraryPath = homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .standardizedDirectoryPath
        return !(path == userLibraryPath || path.hasPrefix(userLibraryPath + "/"))
    }

    private func isSharedSupportApplication(_ path: String) -> Bool {
        path.hasPrefix("/Library/Application Support/")
            && !isKnownInternalPath(path)
    }
}

/// 合并多个候选源，并按标准化路径去重，避免 Spotlight 和文件枚举重复返回同一 bundle。
public struct MergedAppCandidateProvider: AppCandidateProviding {
    public let providers: [any AppCandidateProviding]

    public init(providers: [any AppCandidateProviding]) {
        self.providers = providers
    }

    public func applicationURLs(in scanRoots: [URL]) -> [URL] {
        var urls: [URL] = []
        var seenPaths = Set<String>()

        for provider in providers {
            for url in provider.applicationURLs(in: scanRoots) {
                let path = url.standardizedFileURL.resolvingSymlinksInPath().path
                guard seenPaths.insert(path).inserted else {
                    continue
                }
                urls.append(url)
            }
        }

        return urls
    }
}

private extension URL {
    var isApplicationBundle: Bool {
        pathExtension.caseInsensitiveCompare("app") == .orderedSame
    }

    var standardizedDirectoryPath: String {
        let path = standardizedFileURL.path
        return path.hasSuffix("/") ? String(path.dropLast()) : path
    }

    func isContained(inAnyDirectoryPath rootPaths: [String]) -> Bool {
        let path = standardizedFileURL.path
        return rootPaths.contains { rootPath in
            path == rootPath || path.hasPrefix(rootPath + "/")
        }
    }
}

/// `.app` 文件的时间元数据。
public struct AppFileMetadata: Equatable, Sendable {
    /// Spotlight 记录的系统展示名称，通常与 Finder/Launchpad 中看到的名称一致。
    public let spotlightDisplayName: String?

    /// Spotlight 记录的“添加日期”，优先用于添加时间排序。
    public let spotlightDateAdded: Date?

    /// 文件系统创建时间。
    public let creationDate: Date?

    /// 文件系统修改时间。
    public let modifiedDate: Date?

    public init(
        spotlightDisplayName: String? = nil,
        spotlightDateAdded: Date?,
        creationDate: Date?,
        modifiedDate: Date?
    ) {
        self.spotlightDisplayName = spotlightDisplayName
        self.spotlightDateAdded = spotlightDateAdded
        self.creationDate = creationDate
        self.modifiedDate = modifiedDate
    }
}

/// 应用时间元数据读取协议，方便测试中替换 Spotlight。
public protocol AppMetadataProviding {
    func metadata(for appURL: URL) -> AppFileMetadata
}

/// 基于 Spotlight `MDItem` 和文件系统属性读取应用添加时间。
public struct SpotlightMetadataProvider: AppMetadataProviding {
    public init() {}

    public func metadata(for appURL: URL) -> AppFileMetadata {
        let resourceValues = try? appURL.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])

        return AppFileMetadata(
            spotlightDisplayName: spotlightDisplayName(for: appURL),
            spotlightDateAdded: spotlightDateAdded(for: appURL),
            creationDate: resourceValues?.creationDate,
            modifiedDate: resourceValues?.contentModificationDate
        )
    }

    private func spotlightDisplayName(for appURL: URL) -> String? {
        guard let item = MDItemCreate(kCFAllocatorDefault, appURL.path as CFString),
              let value = MDItemCopyAttribute(item, kMDItemDisplayName) as? String else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private func spotlightDateAdded(for appURL: URL) -> Date? {
        guard let item = MDItemCreate(kCFAllocatorDefault, appURL.path as CFString),
              let value = MDItemCopyAttribute(item, kMDItemDateAdded) else {
            return nil
        }

        if let date = value as? Date {
            return date
        }

        if let date = value as? NSDate {
            return date as Date
        }

        return nil
    }
}
