import AppKit
import Carbon
import OpenLaunchCore
import SwiftUI

/// AppKit 生命周期代理，负责菜单栏状态项和窗口显示控制。
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?
    private var hotkeyManager: HotkeyManager?
    private var escapeHotkeyManager: HotkeyManager?
    private var keyboardMonitor: Any?
    private var scrollMonitor: Any?
    private var workspaceActivationObserver: NSObjectProtocol?
    private let launchWindowController = LaunchWindowController()
    private let state = AppState()
    private var launchWindow: NSWindow?
    private var lastScrollPageTurn = 0.0
    private var isScrollPagingGestureActive = false
    private var scrollPageVerticalTranslation: CGFloat = 0
    private var scrollPagingFinishTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        clearStaleWindowRestorationState()
        configureStatusItem()
        configureHotkey()
        configureKeyboardMonitor()
        configureScrollMonitor()
        configureWorkspaceActivationObserver()
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
        scrollPagingFinishTask?.cancel()
    }

    func applicationDidHide(_ notification: Notification) {
        escapeHotkeyManager = nil
    }

    func applicationDidResignActive(_ notification: Notification) {
        hideOpenLaunchForExternalActivation()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showOpenLaunch()
        return false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    @objc private func showOpenLaunch() {
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
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "square.grid.3x3.fill", accessibilityDescription: "OpenLaunch")
        item.button?.imagePosition = .imageOnly
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked(_:))
        item.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "显示 OpenLaunch", action: #selector(showOpenLaunch), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "重新扫描应用", action: #selector(rescanApplications), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 OpenLaunch", action: #selector(quit), keyEquivalent: "q"))

        statusMenu = menu
        statusItem = item
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let action = StatusItemClickInterpreter.action(
            isSecondaryClick: event?.type == .rightMouseDown,
            isControlPressed: event?.modifierFlags.contains(.control) == true
        )

        switch action {
        case .showLauncher:
            toggleOpenLaunch()
        case .showMenu:
            if let statusMenu {
                statusMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
            }
        }
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
            NotificationCenter.default.post(name: .openLaunchFocusSearch, object: nil)
            return nil
        case kVK_RightArrow:
            state.nextPage()
            NotificationCenter.default.post(name: .openLaunchFocusSearch, object: nil)
            return nil
        case kVK_Delete:
            state.deleteBackwardInSearch()
            NotificationCenter.default.post(name: .openLaunchFocusSearch, object: nil)
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
            try? await Task.sleep(nanoseconds: 140_000_000)
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

        let direction = PageCarouselLayout.targetDirection(
            translation: state.scrollPageTranslation,
            predictedTranslation: state.scrollPageTranslation,
            verticalTranslation: scrollPageVerticalTranslation
        )
        let now = ProcessInfo.processInfo.systemUptime
        let canTurnPage = now - lastScrollPageTurn > 0.18

        withAnimation(pageTurnAnimation) {
            if canTurnPage, let direction {
                switch direction {
                case .previous:
                    state.previousPage()
                case .next:
                    state.nextPage()
                }
                lastScrollPageTurn = now
            }

            state.scrollPageTranslation = 0
        }

        isScrollPagingGestureActive = false
        scrollPageVerticalTranslation = 0
        NotificationCenter.default.post(name: .openLaunchFocusSearch, object: nil)
    }

    private func toggleOpenLaunch() {
        guard let window = openLaunchWindow else {
            showOpenLaunch()
            return
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
        show(window)
    }

    private func clearStaleWindowRestorationState() {
        let defaults = UserDefaults.standard
        let keys = LaunchWindowRestorationPolicy.staleWindowFrameKeys(in: Array(defaults.dictionaryRepresentation().keys))
        keys.forEach(defaults.removeObject(forKey:))
    }

    private func show(_ window: NSWindow) {
        state.backgroundImage = launchWindowController.captureBackgroundImage(for: window)
        launchWindowController.show(window)
        configureEscapeHotkey()
    }

    private func handleWorkspaceActivation(_ notification: Notification) {
        guard let activatedApplication = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              activatedApplication.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return
        }

        hideOpenLaunchForExternalActivation()
    }

    private func hideOpenLaunchForExternalActivation() {
        guard let window = openLaunchWindow, window.isVisible else {
            return
        }

        resetScrollPagingGesture()
        OpenLaunchWindowActions.hide()
    }

    private func resetScrollPagingGesture() {
        scrollPagingFinishTask?.cancel()
        scrollPagingFinishTask = nil
        isScrollPagingGestureActive = false
        scrollPageVerticalTranslation = 0
        state.scrollPageTranslation = 0
    }

    private var pageTurnAnimation: Animation {
        .timingCurve(0.18, 0.86, 0.18, 1.0, duration: Double(LaunchGridLayoutMetrics.pageTurnAnimationDuration))
    }

    private var openLaunchWindow: NSWindow? {
        launchWindow
    }
}
