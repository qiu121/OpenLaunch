import AppKit
import Foundation
import OpenLaunchCore

/// 页面切换方向，用于让不同输入方式共享一致的横向过渡动画。
enum PageTurnDirection {
    case backward
    case forward
}

/// 主界面的状态容器，负责把扫描、排序、搜索、启动和持久化串起来。
@MainActor
final class AppState: ObservableObject {
    @Published var apps: [LaunchableApp] = []
    @Published var settings: OpenLaunchSettings
    @Published var searchText = ""
    @Published var isScanning = false
    @Published var errorMessage: String?
    @Published var currentPage = 0
    @Published var backgroundImage: NSImage?
    @Published var pageTurnDirection: PageTurnDirection = .forward
    @Published var scrollPageTranslation: CGFloat = 0

    private let scanner: AppScanner
    private let store: SettingsStore
    private var recentOpenDates: [String: Date]
    private var applicationRefreshPolicy = ApplicationRefreshPolicy()

    /// 创建应用状态；测试或预览时可传入自定义扫描器和存储位置。
    init(scanner: AppScanner = AppScanner(), store: SettingsStore = SettingsStore()) {
        self.scanner = scanner
        self.store = store
        self.settings = (try? store.loadSettings()) ?? .default
        self.recentOpenDates = (try? store.loadRecentOpenDates()) ?? [:]
    }

    /// 按当前设置排序后的完整应用列表。
    var sortedApps: [LaunchableApp] {
        AppSorter.sorted(apps, using: settings)
    }

    /// 搜索过滤后的应用列表。
    var visibleApps: [LaunchableApp] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return sortedApps
        }

        return sortedApps.filter { $0.matchesSearchQuery(query) }
    }

    var pageSize: Int {
        settings.gridDensity.columns * settings.gridDensity.rows
    }

    /// 分页模式下的总页数。
    var pageCount: Int {
        max(Int(ceil(Double(visibleApps.count) / Double(max(pageSize, 1)))), 1)
    }

    /// 当前页需要展示的应用；滚动模式下由 `visibleApps` 直接驱动。
    var currentPageApps: [LaunchableApp] {
        guard settings.displayMode == .paged else {
            return visibleApps
        }

        let clampedPage = min(max(currentPage, 0), pageCount - 1)
        let start = clampedPage * pageSize
        guard start < visibleApps.count else {
            return []
        }
        let end = min(start + pageSize, visibleApps.count)
        return Array(visibleApps[start..<end])
    }

    /// 异步扫描本机应用目录，并合并 OpenLaunch 自己记录的最近打开时间。
    func scanApplications() {
        isScanning = true
        errorMessage = nil

        Task {
            do {
                let scannedApps = try await Task.detached(priority: .userInitiated) { [scanner, recentOpenDates] in
                    try scanner.scanApplications().map { app in
                        var updatedApp = app
                        updatedApp.lastOpenedDate = recentOpenDates[app.stableKey]
                        return updatedApp
                    }
                }.value

                apps = scannedApps
                currentPage = min(currentPage, pageCount - 1)
            } catch {
                errorMessage = "无法扫描应用：\(error.localizedDescription)"
            }

            isScanning = false
        }
    }

    /// 处理应用目录变化；隐藏时延迟到下次打开，显示时直接刷新列表。
    func handleApplicationDirectoryChange(isLauncherVisible: Bool) {
        performApplicationRefreshAction(
            applicationRefreshPolicy.handleApplicationDirectoryChange(isLauncherVisible: isLauncherVisible)
        )
    }

    /// 启动台显示前消费待刷新标记，让后台安装的新软件在下次打开时出现。
    func refreshApplicationsIfNeededForPresentation() {
        performApplicationRefreshAction(applicationRefreshPolicy.handleLauncherWillShow())
    }

    /// 用户手动重新扫描时清除自动刷新待处理状态，并立即扫描。
    func requestManualApplicationRescan() {
        performApplicationRefreshAction(applicationRefreshPolicy.handleManualRescan())
    }

    private func performApplicationRefreshAction(_ action: ApplicationRefreshAction) {
        switch action {
        case .rescanImmediately:
            scanApplications()
        case .markNeedsRefresh, .noAction:
            break
        }
    }

    /// 更新排序模式并立即保存。
    func updateSortMode(_ sortMode: AppSortMode) {
        if sortMode == .custom {
            ensureCustomOrder()
        }

        settings.sortMode = sortMode
        saveSettings()
    }

    /// 更新完整排序选项；普通排序同时保存方式和方向，自定义排序只保存拖拽顺序。
    func updateSortSelection(_ selection: AppSortSelection) {
        if selection.mode == .custom {
            ensureCustomOrder()
            settings.sortMode = .custom
            settings.sortDirection = .forward
        } else {
            settings.sortMode = selection.mode
            settings.sortDirection = selection.direction ?? .forward
        }

        currentPage = 0
        saveSettings()
    }

    /// 更新排序方向并立即保存；自定义排序始终使用用户拖拽顺序。
    func updateSortDirection(_ sortDirection: AppSortDirection) {
        guard settings.sortMode != .custom else {
            settings.sortDirection = .forward
            saveSettings()
            return
        }

        settings.sortDirection = sortDirection
        currentPage = 0
        saveSettings()
    }

    /// 更新显示模式并立即保存。
    func updateDisplayMode(_ displayMode: DisplayMode) {
        settings.displayMode = displayMode
        currentPage = 0
        saveSettings()
    }

    /// 更新网格密度并立即保存。
    func updateGridDensity(_ density: GridDensity) {
        settings.gridDensity = density
        currentPage = 0
        saveSettings()
    }

    /// 打开启动器时重置临时搜索状态，避免上次焦点或筛选残留。
    func resetSearchSession() {
        searchText = ""
        currentPage = 0
    }

    /// 在自定义排序模式下移动应用，并把结果持久化为稳定顺序。
    func moveAppForCustomSort(draggedAppID: String, targetAppID: String) {
        guard settings.sortMode == .custom,
              searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              draggedAppID != targetAppID else {
            return
        }

        ensureCustomOrder()

        let orderedAppIDs = CustomAppOrder.movedOrder(
            currentAppIDs: sortedApps.map(\.stableKey),
            existingOrder: settings.customOrder,
            draggedAppID: draggedAppID,
            targetAppID: targetAppID
        )
        guard orderedAppIDs != sortedApps.map(\.stableKey) else {
            return
        }

        settings.customOrder = CustomAppOrder.dictionary(from: orderedAppIDs)
        saveSettings()
    }

    func nextPage() {
        let nextPage = min(currentPage + 1, pageCount - 1)
        guard nextPage != currentPage else {
            return
        }

        pageTurnDirection = .forward
        currentPage = nextPage
    }

    func previousPage() {
        let previousPage = max(currentPage - 1, 0)
        guard previousPage != currentPage else {
            return
        }

        pageTurnDirection = .backward
        currentPage = previousPage
    }

    /// 跳转到指定分页，越界时自动夹取到合法范围。
    func goToPage(_ page: Int) {
        let targetPage = min(max(page, 0), pageCount - 1)
        guard targetPage != currentPage else {
            return
        }

        pageTurnDirection = targetPage > currentPage ? .forward : .backward
        currentPage = targetPage
    }

    /// 将普通键盘输入追加到搜索框内容。
    func appendSearchText(_ text: String) {
        searchText.append(text)
        goToPage(0)
    }

    /// 删除搜索框最后一个字符。
    func deleteBackwardInSearch() {
        guard !searchText.isEmpty else {
            return
        }

        searchText.removeLast()
        goToPage(0)
    }

    /// 记录系统中被激活的应用，让最近打开排序能覆盖 Dock 或其它入口打开的应用。
    func recordOpenedApplication(bundleIdentifier: String?, path: String?) {
        guard let index = apps.firstIndex(where: { app in
            if let bundleIdentifier, app.bundleIdentifier == bundleIdentifier {
                return true
            }

            if let path {
                return app.path == path
            }

            return false
        }) else {
            if let bundleIdentifier, !bundleIdentifier.isEmpty {
                recentOpenDates[bundleIdentifier] = Date()
                try? store.saveRecentOpenDates(recentOpenDates)
            }
            return
        }

        recordOpenedApp(at: index)
    }

    /// 通过系统工作区启动应用，成功后记录最近打开时间并隐藏 OpenLaunch。
    func launch(_ app: LaunchableApp) {
        let appURL = URL(fileURLWithPath: app.path, isDirectory: true)
        let configuration = NSWorkspace.OpenConfiguration()

        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { [weak self] _, error in
            Task { @MainActor in
                guard let self else {
                    return
                }

                if let error {
                    self.errorMessage = "无法打开 \(app.displayName)：\(error.localizedDescription)"
                    return
                }

                if let index = self.apps.firstIndex(where: { $0.stableKey == app.stableKey }) {
                    self.recordOpenedApp(at: index)
                } else {
                    self.recentOpenDates[app.stableKey] = Date()
                    try? self.store.saveRecentOpenDates(self.recentOpenDates)
                }
                OpenLaunchWindowActions.hide()
            }
        }
    }

    private func saveSettings() {
        do {
            try store.saveSettings(settings)
        } catch {
            errorMessage = "无法保存设置：\(error.localizedDescription)"
        }
    }

    private func recordOpenedApp(at index: Int) {
        let now = Date()
        let stableKey = apps[index].stableKey
        recentOpenDates[stableKey] = now
        apps[index].lastOpenedDate = now
        try? store.saveRecentOpenDates(recentOpenDates)
    }

    private func ensureCustomOrder() {
        let currentAppIDs = sortedApps.map(\.stableKey)
        settings.customOrder = CustomAppOrder.dictionary(
            from: CustomAppOrder.normalizedOrder(
                currentAppIDs: currentAppIDs,
                existingOrder: settings.customOrder
            )
        )
    }
}
