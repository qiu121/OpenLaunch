import Foundation

/// 应用名称解析结果，包含展示名和搜索时可命中的备用名称。
public struct AppDisplayNameResolution: Equatable, Sendable {
    public let displayName: String
    public let searchAliases: [String]

    public init(displayName: String, searchAliases: [String]) {
        self.displayName = displayName
        self.searchAliases = searchAliases
    }
}

/// 按系统展示习惯解析 `.app` 名称，优先使用 Spotlight 与本地化资源。
public struct AppDisplayNameResolver: Sendable {
    private let preferredLanguages: [String]

    public init(preferredLanguages: [String] = Locale.preferredLanguages) {
        self.preferredLanguages = preferredLanguages
    }

    /// 返回用户可见展示名，并保留原始英文名作为搜索别名。
    public func resolveDisplayName(
        for appURL: URL,
        info: [String: Any],
        metadata: AppFileMetadata
    ) -> AppDisplayNameResolution {
        let rawDisplayName = stringValue(info["CFBundleDisplayName"])
        let rawBundleName = stringValue(info["CFBundleName"])
        let fileName = appURL.deletingPathExtension().lastPathComponent
        let fallbackName = rawDisplayName ?? rawBundleName ?? fileName

        let localizedName = localizedNameFromLoctable(in: appURL)
            ?? localizedNameFromInfoPlistStrings(in: appURL)
        let displayName = preferredDisplayName(
            spotlightDisplayName: metadata.spotlightDisplayName,
            localizedName: localizedName,
            fileName: fileName,
            fallbackName: fallbackName
        )

        let searchAliases = uniqueSearchAliases(
            from: [rawDisplayName, rawBundleName, fileName],
            excluding: displayName
        )

        return AppDisplayNameResolution(displayName: displayName, searchAliases: searchAliases)
    }

    private func preferredDisplayName(
        spotlightDisplayName: String?,
        localizedName: String?,
        fileName: String,
        fallbackName: String
    ) -> String {
        if let spotlightDisplayName,
           normalizedSearchKey(spotlightDisplayName) != normalizedSearchKey(fileName) {
            return spotlightDisplayName
        }

        return localizedName ?? fallbackName
    }

    private func localizedNameFromLoctable(in appURL: URL) -> String? {
        let loctableURL = appURL.appendingPathComponent("Contents/Resources/InfoPlist.loctable")
        guard let table = propertyList(at: loctableURL) as? [String: Any] else {
            return nil
        }

        for localization in preferredLocalizations(from: Array(table.keys)) {
            guard let values = table[localization] as? [String: Any],
                  let displayName = localizedName(in: values) else {
                continue
            }

            return displayName
        }

        return nil
    }

    private func localizedNameFromInfoPlistStrings(in appURL: URL) -> String? {
        let resourcesURL = appURL.appendingPathComponent("Contents/Resources", isDirectory: true)
        guard let localizations = availableLocalizations(in: resourcesURL) else {
            return nil
        }

        for localization in preferredLocalizations(from: localizations) {
            let stringsURL = resourcesURL
                .appendingPathComponent("\(localization).lproj", isDirectory: true)
                .appendingPathComponent("InfoPlist.strings")
            guard let values = propertyList(at: stringsURL) as? [String: Any],
                  let displayName = localizedName(in: values) else {
                continue
            }

            return displayName
        }

        return nil
    }

    private func availableLocalizations(in resourcesURL: URL) -> [String]? {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: resourcesURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        let localizations = urls.compactMap { url -> String? in
            guard url.pathExtension == "lproj" else {
                return nil
            }

            return url.deletingPathExtension().lastPathComponent
        }

        return localizations.isEmpty ? nil : localizations
    }

    private func preferredLocalizations(from availableLocalizations: [String]) -> [String] {
        let selected = Bundle.preferredLocalizations(
            from: availableLocalizations,
            forPreferences: expandedPreferredLanguages()
        )
        let fallbackOrder = expandedPreferredLanguages() + ["Base", "en"]

        return uniqueStrings(from: selected + fallbackOrder + availableLocalizations)
            .filter { availableLocalizations.contains($0) }
    }

    private func expandedPreferredLanguages() -> [String] {
        let expanded = preferredLanguages.flatMap { language -> [String] in
            var candidates = [language]
            let normalized = language.replacingOccurrences(of: "_", with: "-")
            candidates.append(normalized)

            if normalized.hasPrefix("zh-Hans") {
                candidates.append(contentsOf: ["zh-Hans", "zh_CN", "zh"])
            } else if normalized.hasPrefix("zh-Hant") {
                candidates.append(contentsOf: ["zh-Hant", "zh_TW", "zh_HK", "zh"])
            } else if let baseLanguage = normalized.split(separator: "-").first {
                candidates.append(String(baseLanguage))
            }

            candidates.append(normalized.replacingOccurrences(of: "-", with: "_"))
            return candidates
        }

        return uniqueStrings(from: expanded)
    }

    private func localizedName(in values: [String: Any]) -> String? {
        stringValue(values["CFBundleDisplayName"]) ?? stringValue(values["CFBundleName"])
    }

    private func propertyList(at url: URL) -> Any? {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return nil
        }

        return try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
    }

    private func uniqueSearchAliases(from candidates: [String?], excluding displayName: String) -> [String] {
        let displayNameKey = normalizedSearchKey(displayName)
        let aliases = candidates.compactMap { value -> String? in
            guard let value = stringValue(value),
                  normalizedSearchKey(value) != displayNameKey else {
                return nil
            }

            return value
        }

        return uniqueStrings(from: aliases)
    }

    private func uniqueStrings(from values: [String]) -> [String] {
        var seen = Set<String>()
        var uniqueValues: [String] = []

        for value in values {
            let key = normalizedSearchKey(value)
            guard seen.insert(key).inserted else {
                continue
            }

            uniqueValues.append(value)
        }

        return uniqueValues
    }

    private func normalizedSearchKey(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private func stringValue(_ value: Any?) -> String? {
        guard let value else {
            return nil
        }

        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        return nil
    }
}
