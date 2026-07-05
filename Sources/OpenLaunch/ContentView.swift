import AppKit
import OpenLaunchCore
import SwiftUI

/// OpenLaunch 主窗口，展示搜索、排序控制和应用网格。
struct ContentView: View {
    @ObservedObject var state: AppState
    @GestureState private var pageDragTranslation: CGFloat = 0

    private var displayedApps: [LaunchableApp] {
        state.settings.displayMode == .paged ? state.currentPageApps : state.visibleApps
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
            focusSearch()
        }
        .onChange(of: state.searchText) {
            withPageAnimation {
                state.goToPage(0)
            }
        }
        .simultaneousGesture(horizontalPagingGesture)
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
                focusSearch()
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
        .padding(.horizontal, 34)
        .padding(.top, LaunchGridLayoutMetrics.searchTopPadding)
        .padding(.bottom, 30)
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
                .animation(nil, value: pageDragTranslation)
                .animation(nil, value: state.scrollPageTranslation)
            }
            .clipped()
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
                AppTile(app: app, showLabel: state.settings.showLabels) {
                    state.launch(app)
                }
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
        .timingCurve(0.18, 0.86, 0.18, 1.0, duration: Double(LaunchGridLayoutMetrics.pageTurnAnimationDuration))
    }

    private var scrollingGrid: some View {
        ScrollView {
            appGridContent
                .padding(.horizontal, 82)
                .padding(.vertical, 18)
        }
        .scrollIndicators(.hidden)
    }

    private var appGridContent: some View {
        LazyVGrid(columns: gridColumns, spacing: 22) {
            ForEach(displayedApps) { app in
                AppTile(app: app, showLabel: state.settings.showLabels) {
                    state.launch(app)
                }
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
                    focusSearch()
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

    private var horizontalPagingGesture: some Gesture {
        DragGesture(minimumDistance: LaunchGridLayoutMetrics.pageSwipeThreshold)
            .updating($pageDragTranslation) { value, gestureState, _ in
                guard state.settings.displayMode == .paged,
                      isHorizontalDrag(value.translation) else {
                    return
                }

                gestureState = value.translation.width
            }
            .onEnded { value in
                guard state.settings.displayMode == .paged else {
                    return
                }

                guard let direction = PageCarouselLayout.targetDirection(
                    translation: value.translation.width,
                    predictedTranslation: value.predictedEndTranslation.width,
                    verticalTranslation: value.translation.height
                ) else {
                    return
                }

                withPageAnimation {
                    applyPageSwipe(direction)
                }
                focusSearch()
            }
    }

    private func isHorizontalDrag(_ translation: CGSize) -> Bool {
        abs(translation.width) > abs(translation.height) * 1.15
    }

    private func applyPageSwipe(_ direction: PageSwipeInterpreter.Direction) {
        switch direction {
        case .previous:
            state.previousPage()
        case .next:
            state.nextPage()
        }
    }

    private func focusSearch() {
        // `SearchField` 在 SwiftUI 更新时会自动恢复键盘焦点。
    }

    private func withPageAnimation(_ updates: () -> Void) {
        withAnimation(pageTurnAnimation, updates)
    }
}

private struct AppTile: View {
    let app: LaunchableApp
    let showLabel: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: LaunchGridLayoutMetrics.iconSize, height: LaunchGridLayoutMetrics.iconSize)

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
        .buttonStyle(.plain)
        .help(app.displayName)
    }
}
