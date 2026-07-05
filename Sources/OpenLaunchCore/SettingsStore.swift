import Foundation

/// 负责读写 OpenLaunch 的本地 JSON 配置。
public struct SettingsStore {
    /// 配置文件所在的 Application Support 目录。
    public let applicationSupportDirectory: URL

    private var settingsURL: URL {
        applicationSupportDirectory.appendingPathComponent("settings.json")
    }

    private var recentsURL: URL {
        applicationSupportDirectory.appendingPathComponent("recent.json")
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    public init(applicationSupportDirectory: URL = SettingsStore.defaultApplicationSupportDirectory()) {
        self.applicationSupportDirectory = applicationSupportDirectory
    }

    /// 读取用户设置；配置文件不存在时返回默认设置。
    public func loadSettings() throws -> OpenLaunchSettings {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else {
            return .default
        }

        let data = try Data(contentsOf: settingsURL)
        return try decoder.decode(OpenLaunchSettings.self, from: data)
    }

    /// 保存用户设置到 `settings.json`。
    public func saveSettings(_ settings: OpenLaunchSettings) throws {
        try ensureDirectoryExists()
        let data = try encoder.encode(settings)
        try data.write(to: settingsURL, options: .atomic)
    }

    /// 读取应用最近打开时间记录。
    public func loadRecentOpenDates() throws -> [String: Date] {
        guard FileManager.default.fileExists(atPath: recentsURL.path) else {
            return [:]
        }

        let data = try Data(contentsOf: recentsURL)
        return try decoder.decode([String: Date].self, from: data)
    }

    /// 保存应用最近打开时间记录。
    public func saveRecentOpenDates(_ dates: [String: Date]) throws {
        try ensureDirectoryExists()
        let data = try encoder.encode(dates)
        try data.write(to: recentsURL, options: .atomic)
    }

    private func ensureDirectoryExists() throws {
        try FileManager.default.createDirectory(
            at: applicationSupportDirectory,
            withIntermediateDirectories: true
        )
    }

    /// 默认配置目录：`~/Library/Application Support/OpenLaunch`。
    public static func defaultApplicationSupportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)

        return base.appendingPathComponent("OpenLaunch", isDirectory: true)
    }
}
