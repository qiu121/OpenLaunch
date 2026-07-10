import XCTest
@testable import OpenLaunchCore

final class LauncherKeyboardInputPolicyTests: XCTestCase {
    func testPrintableTextFocusesSearchAndForwardsEventForInputMethodComposition() {
        let action = LauncherKeyboardInputPolicy.action(
            keyCode: 0,
            characters: "n",
            charactersIgnoringModifiers: "n",
            containsCommandModifier: false,
            containsControlModifier: false,
            isLauncherVisible: true,
            isSearchFocused: false,
            hasSearchText: false
        )

        XCTAssertEqual(action, .focusSearchAndForwardEvent)
    }

    func testFocusedSearchReceivesPrintableTextDirectly() {
        let action = LauncherKeyboardInputPolicy.action(
            keyCode: 0,
            characters: "n",
            charactersIgnoringModifiers: "n",
            containsCommandModifier: false,
            containsControlModifier: false,
            isLauncherVisible: true,
            isSearchFocused: true,
            hasSearchText: false
        )

        XCTAssertEqual(action, .passThrough)
    }

    func testShortcutModifiersPassThrough() {
        let action = LauncherKeyboardInputPolicy.action(
            keyCode: 45,
            characters: "n",
            charactersIgnoringModifiers: "n",
            containsCommandModifier: true,
            containsControlModifier: false,
            isLauncherVisible: true,
            isSearchFocused: false,
            hasSearchText: false
        )

        XCTAssertEqual(action, .passThrough)
    }

    func testFocusedSearchHandlesStandardEditingShortcuts() {
        XCTAssertEqual(commandAction(forKeyCode: 0, charactersIgnoringModifiers: "a"), .performSearchShortcut(.selectAll))
        XCTAssertEqual(commandAction(forKeyCode: 8, charactersIgnoringModifiers: "c"), .performSearchShortcut(.copy))
        XCTAssertEqual(commandAction(forKeyCode: 7, charactersIgnoringModifiers: "x"), .performSearchShortcut(.cut))
        XCTAssertEqual(commandAction(forKeyCode: 9, charactersIgnoringModifiers: "v"), .performSearchShortcut(.paste))
    }

    func testUnfocusedSearchCanBeFocusedForPasteAndSelectAllShortcuts() {
        XCTAssertEqual(
            commandAction(forKeyCode: 0, charactersIgnoringModifiers: "a", isSearchFocused: false),
            .focusSearchAndPerformShortcut(.selectAll)
        )
        XCTAssertEqual(
            commandAction(forKeyCode: 9, charactersIgnoringModifiers: "v", isSearchFocused: false),
            .focusSearchAndPerformShortcut(.paste)
        )
        XCTAssertEqual(
            commandAction(forKeyCode: 8, charactersIgnoringModifiers: "c", isSearchFocused: false),
            .passThrough
        )
    }

    func testLauncherNavigationKeysKeepExistingBehaviorWhenSearchIsNotFocused() {
        XCTAssertEqual(action(forKeyCode: 53), .hideLauncher)
        XCTAssertEqual(action(forKeyCode: 123), .previousPage)
        XCTAssertEqual(action(forKeyCode: 124), .nextPage)
    }

    func testDeleteRemovesSearchTextOnlyWhenSearchIsNotFocused() {
        XCTAssertEqual(action(forKeyCode: 51, isSearchFocused: false, hasSearchText: true), .deleteBackwardAndFocusSearch)
        XCTAssertEqual(action(forKeyCode: 51, isSearchFocused: true, hasSearchText: true), .passThrough)
    }

    private func action(
        forKeyCode keyCode: Int,
        isSearchFocused: Bool = false,
        hasSearchText: Bool = false
    ) -> LauncherKeyboardInputAction {
        LauncherKeyboardInputPolicy.action(
            keyCode: keyCode,
            characters: nil,
            charactersIgnoringModifiers: nil,
            containsCommandModifier: false,
            containsControlModifier: false,
            isLauncherVisible: true,
            isSearchFocused: isSearchFocused,
            hasSearchText: hasSearchText
        )
    }

    private func commandAction(
        forKeyCode keyCode: Int,
        charactersIgnoringModifiers: String,
        isSearchFocused: Bool = true
    ) -> LauncherKeyboardInputAction {
        LauncherKeyboardInputPolicy.action(
            keyCode: keyCode,
            characters: nil,
            charactersIgnoringModifiers: charactersIgnoringModifiers,
            containsCommandModifier: true,
            containsControlModifier: false,
            isLauncherVisible: true,
            isSearchFocused: isSearchFocused,
            hasSearchText: true
        )
    }
}
