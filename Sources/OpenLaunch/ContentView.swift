import AppKit
import OpenLaunchCore
import SwiftUI
import UniformTypeIdentifiers

/// OpenLaunch 主窗口，展示搜索、排序控制和应用网格。
struct ContentView: View {
    @ObservedObject var state: AppState
    @State private var pageDragTranslation: CGFloat = 0
    @State private var draggingAppID: String?
    @State private var dropTargetAppID: String?
    @State private var enteringAnimatedAppIDs: Set<String> = []

    private var displayedApps: [LaunchableApp] {
        state.settings.displayMode == .paged ? state.currentPageApps : state.visibleApps
    }

    private var isCustomOrderingEnabled: Bool {
        state.settings.sortMode == .custom
            && state.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack(alignment: .top) {
            background
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                header

                if let errorMessage = state.errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.8))
                }

                appGrid

                if state.settings.displayMode == .paged {
                    footer
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.dark)
        .onAppear {
            if state.apps.isEmpty {
                state.scanApplications()
            }
        }
        .onChange(of: state.searchText) {
            withPageAnimation {
                state.goToPage(0)
            }
        }
        .onChange(of: state.presentingAnimatedAppIDs) { _, appIDs in
            playAppEntryAnimation(for: appIDs)
        }
        .onExitCommand {
            OpenLaunchWindowActions.hide()
        }
    }

    private var background: some View {
        GeometryReader { proxy in
            ZStack {
                if let backgroundImage = state.backgroundImage {
                    Image(nsImage: backgroundImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .blur(radius: 34, opaque: true)
                        .clipped()
                } else {
                    VisualEffectBackground()
                }

                Color.black.opacity(0.18)
            }
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            searchBar
            settingsMenu
        }
        .padding(.horizontal, 34)
        .padding(.top, LaunchGridLayoutMetrics.searchTopPadding)
        .padding(.bottom, 30)
    }

    private var searchBar: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 20, height: 20)

            SearchField(text: $state.searchText, placeholder: "搜索应用") {
                OpenLaunchWindowActions.hide()
            }
            .frame(height: LaunchGridLayoutMetrics.searchTextFieldHeight)

            Button {
                state.searchText = ""
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(state.searchText.isEmpty ? .white.opacity(0.0) : .white.opacity(0.55))
            }
            .buttonStyle(.plain)
            .disabled(state.searchText.isEmpty)
        }
        .padding(.horizontal, 14)
        .frame(width: LaunchGridLayoutMetrics.searchHitWidth, height: LaunchGridLayoutMetrics.searchControlHeight)
        .background(searchGlassBackground)
    }

    private var settingsMenu: some View {
        SettingsMenuButton(state: state)
            .frame(width: LaunchGridLayoutMetrics.searchControlHeight, height: LaunchGridLayoutMetrics.searchControlHeight)
            .background(settingsGlassBackground)
            .contentShape(Circle())
        .help("设置")
    }

    private var searchGlassBackground: some View {
        RoundedRectangle(cornerRadius: LaunchGridLayoutMetrics.searchControlHeight / 2, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: LaunchGridLayoutMetrics.searchControlHeight / 2, style: .continuous)
                    .stroke(Color.white.opacity(0.28), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.24), radius: 14, x: 0, y: 5)
    }

    private var settingsGlassBackground: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.24), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
    }

    private var appGrid: some View {
        ZStack(alignment: .top) {
            if state.settings.displayMode == .scroll {
                scrollingGrid
            } else {
                pagedGrid
            }

            if displayedApps.isEmpty {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pagedGrid: some View {
        GeometryReader { proxy in
            let pageWidth = proxy.size.width
            let pageCount = state.pageCount
            let activePageTranslation = pageDragTranslation != 0
                ? pageDragTranslation
                : state.scrollPageTranslation
            let trackOffset = PageCarouselLayout.offset(
                currentPage: state.currentPage,
                pageWidth: pageWidth,
                dragTranslation: activePageTranslation,
                pageCount: pageCount
            )

            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        OpenLaunchWindowActions.hide()
                    }

                HStack(alignment: .top, spacing: 0) {
                    ForEach(0..<pageCount, id: \.self) { page in
                        pagedGridLayer(apps: appsForPage(page), in: proxy.size)
                            .frame(width: pageWidth, height: proxy.size.height, alignment: .topLeading)
                    }
                }
                .frame(width: pageWidth * CGFloat(pageCount), height: proxy.size.height, alignment: .leading)
                .offset(x: trackOffset)
                .animation(pageTurnAnimation, value: state.currentPage)
            }
            .clipped()
            .simultaneousGesture(horizontalPagingGesture(pageWidth: pageWidth))
        }
    }

    private func pagedGridLayer(apps: [LaunchableApp], in size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    OpenLaunchWindowActions.hide()
                }

            ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                animatedAppTile(for: app)
                .position(LaunchGridLayoutMetrics.position(for: index, in: size, settings: state.settings))
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private func appsForPage(_ page: Int) -> [LaunchableApp] {
        let apps = state.visibleApps
        let start = page * state.pageSize
        guard start < apps.count else {
            return []
        }

        let end = min(start + state.pageSize, apps.count)
        return Array(apps[start..<end])
    }

    private var pageTurnAnimation: Animation {
        .interactiveSpring(
            response: Double(LaunchGridLayoutMetrics.pageTurnAnimationDuration),
            dampingFraction: 0.86,
            blendDuration: 0.05
        )
    }

    private var scrollingGrid: some View {
        ScrollView {
            appGridContent
                .padding(.horizontal, 82)
                .padding(.vertical, 18)
        }
        .scrollIndicators(.hidden)
        .background {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    OpenLaunchWindowActions.hide()
                }
        }
    }

    private var appGridContent: some View {
        LazyVGrid(columns: gridColumns, spacing: 22) {
            ForEach(displayedApps) { app in
                animatedAppTile(for: app)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))
            Text(state.isScanning ? "正在扫描应用..." : "没有匹配的应用")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, minHeight: 260)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            ForEach(0..<state.pageCount, id: \.self) { page in
                Button {
                    withPageAnimation {
                        state.goToPage(page)
                    }
                } label: {
                    Circle()
                        .fill(page == state.currentPage ? Color.white : Color.white.opacity(0.3))
                        .frame(
                            width: page == state.currentPage ? 7 : 6,
                            height: page == state.currentPage ? 7 : 6
                        )
                        .frame(width: 30, height: 34)
                        .contentShape(Rectangle())
                }
                    .buttonStyle(.plain)
                    .accessibilityLabel("第 \(page + 1) 页")
                    .help("第 \(page + 1) 页")
            }
        }
        .zIndex(10)
        .padding(.bottom, 28)
    }

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 96, maximum: 136), spacing: 22),
            count: state.settings.gridDensity.columns
        )
    }

    private func horizontalPagingGesture(pageWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: LaunchGridLayoutMetrics.pageGestureMinimumDistance)
            .onChanged { value in
                guard state.settings.displayMode == .paged,
                      isHorizontalDrag(value.translation) else {
                    return
                }

                updatePageDragTranslation(value.translation.width)
            }
            .onEnded { value in
                guard state.settings.displayMode == .paged else {
                    resetPageDragTranslation()
                    return
                }

                let targetPage = PageCarouselLayout.snapTargetPage(
                    currentPage: state.currentPage,
                    pageWidth: pageWidth,
                    translation: value.translation.width,
                    predictedTranslation: value.predictedEndTranslation.width,
                    verticalTranslation: value.translation.height,
                    pageCount: state.pageCount
                )

                withPageAnimation {
                    state.goToPage(targetPage)
                    pageDragTranslation = 0
                }
            }
    }

    private func isHorizontalDrag(_ translation: CGSize) -> Bool {
        abs(translation.width) > abs(translation.height) * 1.15
    }

    private func updatePageDragTranslation(_ translation: CGFloat) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            pageDragTranslation = translation
        }
    }

    private func resetPageDragTranslation() {
        withPageAnimation {
            pageDragTranslation = 0
        }
    }

    private func appTile(for app: LaunchableApp) -> some View {
        AppTile(
            app: app,
            showLabel: state.settings.showLabels,
            isCustomOrderingEnabled: isCustomOrderingEnabled,
            draggingAppID: $draggingAppID,
            dropTargetAppID: $dropTargetAppID,
            insertionEdge: insertionEdge(for: app)
        ) {
            state.launch(app)
        } moveAction: { draggedAppID, targetAppID in
            withPageAnimation {
                state.moveAppForCustomSort(draggedAppID: draggedAppID, targetAppID: targetAppID)
            }
        }
    }

    private func animatedAppTile(for app: LaunchableApp) -> some View {
        let isEntering = enteringAnimatedAppIDs.contains(app.stableKey)

        return appTile(for: app)
            .scaleEffect(isEntering ? 0.82 : 1.0)
            .opacity(isEntering ? 0.0 : 1.0)
            .animation(appEntryAnimation, value: enteringAnimatedAppIDs)
    }

    private func insertionEdge(for app: LaunchableApp) -> CustomInsertionEdge? {
        guard dropTargetAppID == app.stableKey,
              let draggingAppID,
              draggingAppID != app.stableKey else {
            return nil
        }

        let orderedAppIDs = state.sortedApps.map(\.stableKey)
        guard let sourceIndex = orderedAppIDs.firstIndex(of: draggingAppID),
              let targetIndex = orderedAppIDs.firstIndex(of: app.stableKey) else {
            return .before
        }

        return sourceIndex < targetIndex ? .after : .before
    }

    private func withPageAnimation(_ updates: () -> Void) {
        withAnimation(pageTurnAnimation, updates)
    }

    private var appEntryAnimation: Animation {
        .interactiveSpring(response: 0.34, dampingFraction: 0.78, blendDuration: 0.04)
    }

    private func playAppEntryAnimation(for appIDs: Set<String>) {
        guard !appIDs.isEmpty else {
            return
        }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            enteringAnimatedAppIDs = appIDs
        }

        DispatchQueue.main.async {
            withAnimation(appEntryAnimation) {
                enteringAnimatedAppIDs.subtract(appIDs)
            }
            state.finishAppListChangeAnimationPresentation()
        }
    }
}

private struct AppTile: View {
    let app: LaunchableApp
    let showLabel: Bool
    let isCustomOrderingEnabled: Bool
    @Binding var draggingAppID: String?
    @Binding var dropTargetAppID: String?
    let insertionEdge: CustomInsertionEdge?
    let action: () -> Void
    let moveAction: (_ draggedAppID: String, _ targetAppID: String) -> Void

    @ViewBuilder
    var body: some View {
        if isCustomOrderingEnabled {
            tileContent
                .offset(x: insertionOffset)
                .overlay(alignment: .center) {
                    customDropIndicator
                }
                .animation(dropPreviewAnimation, value: insertionEdge)
                .onDrag {
                    draggingAppID = app.stableKey
                    return NSItemProvider(object: app.stableKey as NSString)
                }
                .onDrop(
                    of: [UTType.text],
                    delegate: AppTileDropDelegate(
                        appID: app.stableKey,
                        draggingAppID: $draggingAppID,
                        dropTargetAppID: $dropTargetAppID,
                        moveAction: moveAction
                    )
                )
                .help("拖动以调整顺序")
        } else {
            appButton
        }
    }

    private var dropPreviewAnimation: Animation {
        .interactiveSpring(response: 0.22, dampingFraction: 0.82, blendDuration: 0.02)
    }

    private var insertionOffset: CGFloat {
        guard let insertionEdge else {
            return 0
        }

        return insertionEdge == .before ? 12 : -12
    }

    private var appButton: some View {
        Button(action: action) {
            tileContent
        }
        .buttonStyle(.plain)
        .help(app.displayName)
    }

    private var tileContent: some View {
        VStack(spacing: 6) {
            AppIconImage(path: app.path)

            if showLabel {
                Text(app.displayName)
                    .font(.caption.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 34, alignment: .top)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.65), radius: 2, x: 0, y: 1)
            }
        }
        .frame(
            width: LaunchGridLayoutMetrics.tileWidth,
            height: showLabel ? LaunchGridLayoutMetrics.labeledTileHeight : LaunchGridLayoutMetrics.iconOnlyTileHeight
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var customDropIndicator: some View {
        if let insertionEdge {
            insertionSlot(for: insertionEdge)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .allowsHitTesting(false)
        }
    }

    private func insertionSlot(for edge: CustomInsertionEdge) -> some View {
        let slotOffset = edge == .before
            ? -LaunchGridLayoutMetrics.tileWidth / 2 + 12
            : LaunchGridLayoutMetrics.tileWidth / 2 - 12

        return RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.ultraThinMaterial)
            .frame(width: 34, height: LaunchGridLayoutMetrics.iconSize + 18)
            .overlay {
                Capsule()
                    .fill(Color.white.opacity(0.82))
                    .frame(width: 5, height: LaunchGridLayoutMetrics.iconSize * 0.74)
                    .shadow(color: .white.opacity(0.22), radius: 5, x: 0, y: 0)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.24), radius: 10, x: 0, y: 4)
            .offset(x: slotOffset, y: -14)
    }
}

private enum CustomInsertionEdge {
    case before
    case after
}

private struct AppTileDropDelegate: DropDelegate {
    let appID: String
    @Binding var draggingAppID: String?
    @Binding var dropTargetAppID: String?
    let moveAction: (_ draggedAppID: String, _ targetAppID: String) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        guard let draggingAppID else {
            return false
        }

        return draggingAppID != appID
    }

    func dropEntered(info: DropInfo) {
        guard validateDrop(info: info) else {
            return
        }

        withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.84, blendDuration: 0.02)) {
            dropTargetAppID = appID
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        guard dropTargetAppID == appID else {
            return
        }

        withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.84, blendDuration: 0.02)) {
            dropTargetAppID = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let draggingAppID, draggingAppID != appID else {
            self.draggingAppID = nil
            dropTargetAppID = nil
            return false
        }

        moveAction(draggingAppID, appID)
        self.draggingAppID = nil
        dropTargetAppID = nil
        return true
    }
}

private struct AppIconImage: View {
    let path: String

    var body: some View {
        Image(nsImage: icon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: LaunchGridLayoutMetrics.iconSize, height: LaunchGridLayoutMetrics.iconSize)
    }

    private var icon: NSImage {
        let resolvedPath = URL(fileURLWithPath: path, isDirectory: true)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
        let bundleIcon = NSWorkspace.shared.icon(forFile: resolvedPath)
        bundleIcon.size = NSSize(width: LaunchGridLayoutMetrics.iconSize, height: LaunchGridLayoutMetrics.iconSize)
        return bundleIcon
    }
}

private struct SettingsMenuButton: NSViewRepresentable {
    @ObservedObject var state: AppState

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state)
    }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: "设置")
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = NSColor.white.withAlphaComponent(0.78)
        button.target = context.coordinator
        button.action = #selector(Coordinator.showMenu(_:))
        button.focusRingType = .none
        button.toolTip = "设置"
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        context.coordinator.state = state
    }

    @MainActor
    final class Coordinator: NSObject {
        var state: AppState

        init(state: AppState) {
            self.state = state
        }

        @objc func showMenu(_ sender: NSButton) {
            let menu = makeMenu()
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
        }

        @objc private func updateSortSelection(_ sender: NSMenuItem) {
            guard let selectionID = sender.representedObject as? String,
                  let sortSelection = AppSortSelection.option(withID: selectionID) else {
                return
            }

            state.updateSortSelection(sortSelection)
        }

        @objc private func updateDisplayMode(_ sender: NSMenuItem) {
            guard let rawValue = sender.representedObject as? String,
                  let displayMode = DisplayMode(rawValue: rawValue) else {
                return
            }

            state.updateDisplayMode(displayMode)
        }

        @objc private func rescanApplications() {
            state.requestManualApplicationRescan()
        }

        private func makeMenu() -> NSMenu {
            let menu = NSMenu()
            addSortingItems(to: menu)
            menu.addItem(.separator())
            addDisplayItems(to: menu)
            menu.addItem(.separator())
            menu.addItem(NSMenuItem(title: "重新扫描", action: #selector(rescanApplications), keyEquivalent: ""))
            menu.items.last?.target = self
            return menu
        }

        private func addSortingItems(to menu: NSMenu) {
            let headerItem = NSMenuItem(title: "排序方式", action: nil, keyEquivalent: "")
            headerItem.isEnabled = false
            menu.addItem(headerItem)

            let currentSortSelection = AppSortSelection.current(for: state.settings)
            for group in AppSortMenuLayout.groups {
                if group.options.count == 1, let option = group.options.first {
                    menu.addItem(sortMenuItem(for: option, currentSelection: currentSortSelection))
                    continue
                }

                let groupItem = NSMenuItem(title: group.title, action: nil, keyEquivalent: "")
                groupItem.state = state.settings.sortMode == group.mode ? .on : .off
                groupItem.image = NSImage(systemSymbolName: group.systemImageName, accessibilityDescription: group.title)

                let groupMenu = NSMenu()
                for option in group.options {
                    groupMenu.addItem(sortMenuItem(for: option, currentSelection: currentSortSelection))
                }
                groupItem.submenu = groupMenu
                menu.addItem(groupItem)
            }
        }

        private func addDisplayItems(to menu: NSMenu) {
            let headerItem = NSMenuItem(title: "显示模式", action: nil, keyEquivalent: "")
            headerItem.isEnabled = false
            menu.addItem(headerItem)

            let displayModeItems: [(String, DisplayMode)] = [
                ("分页", .paged),
                ("滚动", .scroll)
            ]

            for mode in displayModeItems {
                let item = NSMenuItem(title: mode.0, action: #selector(updateDisplayMode(_:)), keyEquivalent: "")
                item.representedObject = mode.1.rawValue
                item.target = self
                item.state = state.settings.displayMode == mode.1 ? .on : .off
                item.image = NSImage(systemSymbolName: systemImageName(for: mode.1), accessibilityDescription: mode.0)
                menu.addItem(item)
            }
        }

        private func sortMenuItem(for option: AppSortSelection, currentSelection: AppSortSelection) -> NSMenuItem {
            let item = NSMenuItem(title: option.title, action: #selector(updateSortSelection(_:)), keyEquivalent: "")
            item.representedObject = option.id
            item.target = self
            item.state = currentSelection == option ? .on : .off
            item.image = NSImage(systemSymbolName: option.systemImageName, accessibilityDescription: option.title)
            return item
        }

        private func systemImageName(for displayMode: DisplayMode) -> String {
            switch displayMode {
            case .paged:
                return "square.grid.3x3"
            case .scroll:
                return "scroll"
            }
        }
    }
}

private extension DisplayMode {
    var menuTitle: String {
        switch self {
        case .paged:
            return "分页"
        case .scroll:
            return "滚动"
        }
    }

    var menuSymbolName: String {
        switch self {
        case .paged:
            return "square.grid.3x3"
        case .scroll:
            return "scroll"
        }
    }
}
