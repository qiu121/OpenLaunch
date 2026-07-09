import Foundation

/// 启动台全局键盘事件的处理意图；文本输入必须交还给系统输入法。
public enum LauncherKeyboardInputAction: Equatable, Sendable {
    case passThrough
    case hideLauncher
    case previousPage
    case nextPage
    case deleteBackwardAndFocusSearch
    case focusSearchAndForwardEvent
}

/// 将 AppKit 键盘事件压缩成可测试的启动台输入策略。
public enum LauncherKeyboardInputPolicy {
    private static let escapeKeyCode = 53
    private static let deleteKeyCode = 51
    private static let leftArrowKeyCode = 123
    private static let rightArrowKeyCode = 124

    public static func action(
        keyCode: Int,
        characters: String?,
        containsCommandModifier: Bool,
        containsControlModifier: Bool,
        isLauncherVisible: Bool,
        isSearchFocused: Bool,
        hasSearchText: Bool
    ) -> LauncherKeyboardInputAction {
        guard isLauncherVisible else {
            return .passThrough
        }

        if isSearchFocused {
            return .passThrough
        }

        switch keyCode {
        case escapeKeyCode:
            return .hideLauncher
        case leftArrowKeyCode:
            return .previousPage
        case rightArrowKeyCode:
            return .nextPage
        case deleteKeyCode where hasSearchText:
            return .deleteBackwardAndFocusSearch
        default:
            break
        }

        guard isPrintableTextInput(
            characters: characters,
            containsCommandModifier: containsCommandModifier,
            containsControlModifier: containsControlModifier
        ) else {
            return .passThrough
        }

        return .focusSearchAndForwardEvent
    }

    private static func isPrintableTextInput(
        characters: String?,
        containsCommandModifier: Bool,
        containsControlModifier: Bool
    ) -> Bool {
        guard !containsCommandModifier,
              !containsControlModifier,
              let characters,
              !characters.isEmpty else {
            return false
        }

        return characters.rangeOfCharacter(from: .controlCharacters) == nil
    }
}
