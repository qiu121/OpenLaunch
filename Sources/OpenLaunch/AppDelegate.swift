import AppKit
import Carbon
import OpenLaunchCore
import SwiftUI

/// AppKit 生命周期代理，负责菜单栏状态项和窗口显示控制。
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?
    private var hotkeyManager: HotkeyManager?
    private var escapeHotkeyManager: HotkeyManager?
    private var keyboardMonitor: Any?
    private var scrollMonitor: Any?
    private var workspaceActivationObserver: NSObjectProtocol?
    private var launcherDidHideObserver: NSObjectProtocol?
    private let launchWindowController = LaunchWindowController()
    private let menuBarTriggerShield = MenuBarTriggerShield()
    private let state = AppState()
    private var launchWindow: NSWindow?
    private var lastScrollPageTurn = 0.0
    private var isScrollPagingGestureActive = false
    private var scrollPageVerticalTranslation: CGFloat = 0
    private var scrollPagingFinishTask: Task<Void, Never>?
    private var lastStatusItemActionTimestamp = 0.0
    private var statusMenuWasPresentedFromVisibleLauncher = false
    private var restoreLauncherInputTask: Task<Void, Never>?
    private var initialLaunchPresentationWorkItem: DispatchWorkItem?
    private var suppressExternalActivationUntil = 0.0

    func applicationDidFinishLaunching(_ notification: Notification) {
        clearStaleWindowRestorationState()
        configureStatusItem()
        configureHotkey()
        configureKeyboardMonitor()
        configureScrollMonitor()
        configureWorkspaceActivationObserver()
        configureLauncherVisibilityObserver()
        createLaunchWindow()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let keyboardMonitor {
            NSEvent.removeMonitor(keyboardMonitor)
        }
        if let scrollMonitor {
            NSEvent.removeMonitor(scrollMonitor)
        }
        if let workspaceActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceActivationObserver)
        }
        if let launcherDidHideObserver {
            NotificationCenter.default.removeObserver(launcherDidHideObserver)
        }
        scrollPagingFinishTask?.cancel()
        restoreLauncherInputTask?.cancel()
        initialLaunchPresentationWorkItem?.cancel()
    }

    func applicationDidHide(_ notification: Notification) {
        escapeHotkeyManager = nil
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard let window = openLaunchWindow, isLauncherWindowVisible(window) else {
            return
        }

        launchWindowController.hideMenuBarIfPossible()
    }

    func applicationDidResignActive(_ notification: Notification) {
        guard LauncherChromePolicy.hidesOnApplicationResignActive else {
            return
        }

        hideOpenLaunchForExternalActivation()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        toggleOpenLaunch()
        return false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        LaunchWindowRestorationPolicy.supportsSecureRestorableState
    }

    @objc private func showOpenLaunch() {
        cancelInitialLaunchPresentation()
        if let window = openLaunchWindow {
            show(window)
        }
    }

    @objc private func rescanApplications() {
        showOpenLaunch()
        state.scanApplications()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc func cancelOperation(_ sender: Any?) {
        OpenLaunchWindowActions.hide()
    }

    private func configureStatusItem() {
        if statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            item.button?.image = NSImage(systemSymbolName: "square.grid.3x3.fill", accessibilityDescription: "OpenLaunch")
            item.button?.imagePosition = .imageOnly
            item.button?.target = self
            item.button?.action = #selector(statusItemClicked(_:))
            item.button?.sendAction(on: [.leftMouseUp, .rightMouseDown])
            statusItem = item
        }

        statusMenu = makeStatusMenu()
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        StatusMenuPolicy.items
            .map(statusMenuItem)
            .forEach(menu.addItem)
        return menu
    }

    private func statusMenuItem(for policyItem: StatusMenuPolicy.Item) -> NSMenuItem {
        let item = NSMenuItem(title: policyItem.title, action: selector(for: policyItem.action), keyEquivalent: "")
        item.target = self
        if policyItem.action == .quit {
            item.keyEquivalent = "q"
        }
        return item
    }

    private func selector(for action: StatusMenuPolicy.Action) -> Selector {
        switch action {
        case .rescanApplications:
            return #selector(rescanApplications)
        case .quit:
            return #selector(quit)
        }
    }

    nonisolated func menuDidClose(_ menu: NSMenu) {
        Task { @MainActor [weak self] in
            self?.finishStatusMenuInteraction()
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        defer {
            clearStatusItemHighlightAfterMenuSettles()
        }

        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastStatusItemActionTimestamp > 0.08 else {
            return
        }
        lastStatusItemActionTimestamp = now

        let event = NSApp.currentEvent
        let action = StatusItemClickInterpreter.action(
            isSecondaryClick: event?.type == .rightMouseDown,
            isControlPressed: event?.modifierFlags.contains(.control) == true
        )

        switch action {
        case .showLauncher:
            toggleOpenLaunch()
        case .showMenu:
            presentStatusMenu(from: sender)
        }
    }

    private func presentStatusMenu(from sender: NSStatusBarButton) {
        guard let statusItem else {
            return
        }

        let menu = makeStatusMenu()
        statusMenu = menu
        statusMenuWasPresentedFromVisibleLauncher = openLaunchWindow.map(isLauncherWindowVisible) ?? false

        sender.isHighlighted = true
        statusItem.menu = menu
        sender.performClick(nil)
    }

    private func finishStatusMenuInteraction() {
        statusItem?.menu = nil
        clearStatusItemHighlightAfterMenuSettles()
        restoreLauncherInputAfterStatusMenuIfNeeded()
    }

    private func restoreLauncherInputAfterStatusMenuIfNeeded() {
        guard statusMenuWasPresentedFromVisibleLauncher else {
            return
        }

        statusMenuWasPresentedFromVisibleLauncher = false
        restoreLauncherInputTask?.cancel()
        restoreLauncherInputTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 90_000_000)
            self?.restoreLauncherInputIfVisible()
        }
    }

    private func restoreLauncherInputIfVisible() {
        guard let window = openLaunchWindow, isLauncherWindowVisible(window) else {
            return
        }

        resetScrollPagingGesture()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(nil)
        clearStatusItemHighlight()
    }

    private func clearStatusItemHighlightAfterMenuSettles() {
        Task { @MainActor [weak self] in
            self?.clearStatusItemHighlight()
            try? await Task.sleep(nanoseconds: 80_000_000)
            self?.clearStatusItemHighlight()
        }
    }

    private func clearStatusItemHighlight() {
        guard let button = statusItem?.button else {
            return
        }

        button.isHighlighted = false
        button.needsDisplay = true
    }

    private func configureHotkey() {
        hotkeyManager = HotkeyManager(keyCode: UInt32(kVK_ANSI_L), modifiers: UInt32(cmdKey | optionKey | controlKey)) {
            Task { @MainActor [weak self] in
                self?.toggleOpenLaunch()
            }
        }
    }

    private func configureEscapeHotkey() {
        escapeHotkeyManager = HotkeyManager(keyCode: UInt32(kVK_Escape), modifiers: 0, id: 2) {
            Task { @MainActor in
                OpenLaunchWindowActions.hide()
            }
        }
    }

    private func configureKeyboardMonitor() {
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else {
                return event
            }

            return self.handleKeyDown(event)
        }
    }

    private func configureScrollMonitor() {
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else {
                return event
            }

            return self.handleScrollWheel(event)
        }
    }

    private func configureWorkspaceActivationObserver() {
        workspaceActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else {
                return
            }

            Task { @MainActor in
                self.handleWorkspaceActivation(notification)
            }
        }
    }

    private func configureLauncherVisibilityObserver() {
        launcherDidHideObserver = NotificationCenter.default.addObserver(
            forName: .openLaunchDidHide,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else {
                return
            }

            Task { @MainActor in
                self.restoreChromeAfterLauncherHides()
            }
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        guard let window = openLaunchWindow, window.isVisible else {
            return event
        }

        switch Int(event.keyCode) {
        case kVK_Escape:
            OpenLaunchWindowActions.hide()
            return nil
        case kVK_LeftArrow:
            state.previousPage()
            return nil
        case kVK_RightArrow:
            state.nextPage()
            return nil
        case kVK_Delete:
            let hadSearchText = !state.searchText.isEmpty
            state.deleteBackwardInSearch()
            if hadSearchText {
                NotificationCenter.default.post(name: .openLaunchFocusSearch, object: nil)
            }
            return nil
        default:
            break
        }

        guard !event.modifierFlags.contains(.command),
              !event.modifierFlags.contains(.control),
              let characters = event.characters,
              characters.rangeOfCharacter(from: .controlCharacters) == nil,
              !characters.isEmpty else {
            return event
        }

        state.appendSearchText(characters)
        NotificationCenter.default.post(name: .openLaunchFocusSearch, object: nil)
        return nil
    }

    private func handleScrollWheel(_ event: NSEvent) -> NSEvent? {
        guard let window = openLaunchWindow,
              window.isVisible,
              state.settings.displayMode == .paged else {
            resetScrollPagingGesture()
            return event
        }

        if event.momentumPhase != [] {
            return nil
        }

        let horizontalIntent = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
        guard horizontalIntent || isScrollPagingGestureActive else {
            return event
        }

        updateScrollPagingGesture(with: event)
        return nil
    }

    private func updateScrollPagingGesture(with event: NSEvent) {
        if event.phase.contains(.began) || !isScrollPagingGestureActive {
            beginScrollPagingGesture()
        }

        scrollPagingFinishTask?.cancel()
        state.scrollPageTranslation += event.scrollingDeltaX
        scrollPageVerticalTranslation += event.scrollingDeltaY

        if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            finishScrollPagingGesture()
            return
        }

        scrollPagingFinishTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: LaunchGridLayoutMetrics.scrollPagingIdleFinishDelayNanoseconds)
            self?.finishScrollPagingGesture()
        }
    }

    private func beginScrollPagingGesture() {
        isScrollPagingGestureActive = true
        scrollPageVerticalTranslation = 0
        state.scrollPageTranslation = 0
    }

    private func finishScrollPagingGesture() {
        guard isScrollPagingGestureActive else {
            return
        }

        let currentPage = state.currentPage
        let targetPage = PageCarouselLayout.snapTargetPage(
            currentPage: currentPage,
            pageWidth: openLaunchWindow?.contentView?.bounds.width ?? openLaunchWindow?.frame.width ?? 1,
            translation: state.scrollPageTranslation,
            predictedTranslation: state.scrollPageTranslation,
            verticalTranslation: scrollPageVerticalTranslation,
            pageCount: state.pageCount
        )
        let now = ProcessInfo.processInfo.systemUptime
        let canTurnPage = now - lastScrollPageTurn > 0.18

        withAnimation(pageTurnAnimation) {
            if canTurnPage, targetPage != currentPage {
                state.goToPage(targetPage)
                lastScrollPageTurn = now
            }

            state.scrollPageTranslation = 0
        }

        isScrollPagingGestureActive = false
        scrollPageVerticalTranslation = 0
    }

    @objc private func toggleOpenLaunch() {
        cancelInitialLaunchPresentation()
        guard let window = openLaunchWindow else {
            showOpenLaunch()
            return
        }

        if isLauncherWindowVisible(window) {
            resetScrollPagingGesture()
        }

        launchWindowController.toggle(window)
    }

    private func createLaunchWindow() {
        let window = LauncherWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 450),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "OpenLaunch"
        window.contentView = NSHostingView(rootView: ContentView(state: state))
        launchWindow = window
        scheduleInitialLaunchPresentation(for: window)
    }

    private func scheduleInitialLaunchPresentation(for window: NSWindow) {
        cancelInitialLaunchPresentation()
        let workItem = DispatchWorkItem { [weak self, weak window] in
            guard let self, let window else {
                return
            }

            self.initialLaunchPresentationWorkItem = nil
            self.show(window)
        }
        initialLaunchPresentationWorkItem = workItem

        let delay = DispatchTimeInterval.nanoseconds(Int(LauncherChromePolicy.initialPresentationDelayNanoseconds))
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func cancelInitialLaunchPresentation() {
        initialLaunchPresentationWorkItem?.cancel()
        initialLaunchPresentationWorkItem = nil
    }

    private func clearStaleWindowRestorationState() {
        let defaults = UserDefaults.standard
        let keys = LaunchWindowRestorationPolicy.staleWindowFrameKeys(in: Array(defaults.dictionaryRepresentation().keys))
        keys.forEach(defaults.removeObject(forKey:))
    }

    private func show(_ window: NSWindow) {
        suppressExternalActivationDuringPresentation()
        if LauncherChromePolicy.usesRegularActivationDuringPresentation {
            NSApp.setActivationPolicy(.regular)
        }

        resetScrollPagingGesture()
        state.resetSearchSession()
        state.backgroundImage = launchWindowController.captureBackgroundImage(for: window)
        prepareChromeForLauncherPresentation(on: launchWindowController.targetScreen(for: window))
        launchWindowController.show(window)
        if LauncherChromePolicy.returnsToAccessoryImmediatelyAfterPresentation {
            NSApp.setActivationPolicy(.accessory)
        }
        window.makeFirstResponder(nil)
        NotificationCenter.default.post(name: .openLaunchBlurSearch, object: nil)
        configureEscapeHotkey()
    }

    private func handleWorkspaceActivation(_ notification: Notification) {
        guard ProcessInfo.processInfo.systemUptime >= suppressExternalActivationUntil else {
            return
        }

        guard let activatedApplication = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              activatedApplication.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return
        }

        state.recordOpenedApplication(
            bundleIdentifier: activatedApplication.bundleIdentifier,
            path: activatedApplication.bundleURL?.path
        )
        hideOpenLaunchForExternalActivation()
    }

    private func hideOpenLaunchForExternalActivation() {
        guard let window = openLaunchWindow, window.isVisible else {
            return
        }

        resetScrollPagingGesture()
        OpenLaunchWindowActions.hide()
    }

    private func isLauncherWindowVisible(_ window: NSWindow) -> Bool {
        window.isVisible && window.alphaValue > 0.02
    }

    private func resetScrollPagingGesture() {
        scrollPagingFinishTask?.cancel()
        scrollPagingFinishTask = nil
        isScrollPagingGestureActive = false
        scrollPageVerticalTranslation = 0
        state.scrollPageTranslation = 0
    }

    private func suppressExternalActivationDuringPresentation() {
        let suppressionDuration = Double(LauncherChromePolicy.externalActivationSuppressionAfterPresentationNanoseconds) / 1_000_000_000
        suppressExternalActivationUntil = ProcessInfo.processInfo.systemUptime + suppressionDuration
    }

    private func prepareChromeForLauncherPresentation(on screen: NSScreen?) {
        if LauncherChromePolicy.hidesStatusItemWhileLauncherVisible {
            statusItem?.isVisible = false
        }
        menuBarTriggerShield.show(on: screen)
    }

    private func restoreChromeAfterLauncherHides() {
        menuBarTriggerShield.hide()
        if LauncherChromePolicy.hidesStatusItemWhileLauncherVisible {
            statusItem?.isVisible = true
        }
    }

    private var pageTurnAnimation: Animation {
        .interactiveSpring(
            response: Double(LaunchGridLayoutMetrics.pageTurnAnimationDuration),
            dampingFraction: 0.86,
            blendDuration: 0.05
        )
    }

    private var openLaunchWindow: NSWindow? {
        launchWindow
    }
}
