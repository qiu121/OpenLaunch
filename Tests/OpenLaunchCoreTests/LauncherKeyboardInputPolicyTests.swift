import XCTest
@testable import OpenLaunchCore

final class LauncherKeyboardInputPolicyTests: XCTestCase {
    func testPrintableTextFocusesSearchAndForwardsEventForInputMethodComposition() {
        let action = LauncherKeyboardInputPolicy.action(
            keyCode: 0,
            characters: "n",
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
            keyCode: 0,
            characters: "n",
            containsCommandModifier: true,
            containsControlModifier: false,
            isLauncherVisible: true,
            isSearchFocused: false,
            hasSearchText: false
        )

        XCTAssertEqual(action, .passThrough)
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
            containsCommandModifier: false,
            containsControlModifier: false,
            isLauncherVisible: true,
            isSearchFocused: isSearchFocused,
            hasSearchText: hasSearchText
        )
    }
}
