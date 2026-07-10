import Foundation

/// 启动台全局键盘事件的处理意图；文本输入必须交还给系统输入法。
public enum LauncherKeyboardInputAction: Equatable, Sendable {
    case passThrough
    case hideLauncher
    case previousPage
    case nextPage
    case deleteBackwardAndFocusSearch
    case focusSearchAndForwardEvent
    case performSearchShortcut(LauncherSearchShortcut)
    case focusSearchAndPerformShortcut(LauncherSearchShortcut)
}

/// 搜索框支持的基础编辑快捷键。
public enum LauncherSearchShortcut: Equatable, Sendable {
    case selectAll
    case copy
    case cut
    case paste
}

/// 将 AppKit 键盘事件压缩成可测试的启动台输入策略。
public enum LauncherKeyboardInputPolicy {
    private static let escapeKeyCode = 53
    private static let deleteKeyCode = 51
    private static let leftArrowKeyCode = 123
    private static let rightArrowKeyCode = 124
    private static let aKeyCode = 0
    private static let cKeyCode = 8
    private static let vKeyCode = 9
    private static let xKeyCode = 7

    public static func action(
        keyCode: Int,
        characters: String?,
        charactersIgnoringModifiers: String?,
        containsCommandModifier: Bool,
        containsControlModifier: Bool,
        isLauncherVisible: Bool,
        isSearchFocused: Bool,
        hasSearchText: Bool
    ) -> LauncherKeyboardInputAction {
        guard isLauncherVisible else {
            return .passThrough
        }

        if let shortcut = searchShortcut(
            keyCode: keyCode,
            charactersIgnoringModifiers: charactersIgnoringModifiers,
            containsCommandModifier: containsCommandModifier,
            containsControlModifier: containsControlModifier
        ) {
            if isSearchFocused {
                return .performSearchShortcut(shortcut)
            }

            switch shortcut {
            case .selectAll, .paste:
                return .focusSearchAndPerformShortcut(shortcut)
            case .copy, .cut:
                return .passThrough
            }
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

    private static func searchShortcut(
        keyCode: Int,
        charactersIgnoringModifiers: String?,
        containsCommandModifier: Bool,
        containsControlModifier: Bool
    ) -> LauncherSearchShortcut? {
        guard containsCommandModifier, !containsControlModifier else {
            return nil
        }

        switch keyCode {
        case aKeyCode:
            return .selectAll
        case cKeyCode:
            return .copy
        case vKeyCode:
            return .paste
        case xKeyCode:
            return .cut
        default:
            break
        }

        switch charactersIgnoringModifiers?.lowercased() {
        case "a":
            return .selectAll
        case "c":
            return .copy
        case "v":
            return .paste
        case "x":
            return .cut
        default:
            return nil
        }
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
