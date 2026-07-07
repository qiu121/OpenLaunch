/// 启动器显示和隐藏时的搜索会话清理策略，避免文本、页码或插入光标跨会话残留。
public enum LauncherSearchSessionPolicy {
    public enum Event: Equatable, Sendable {
        case willShow
        case didShow
        case didHide
    }

    public enum Action: Equatable, Sendable {
        case resetSearchSession
        case blurSearchField
        case deferredBlurSearchField
    }

    public static func actions(for event: Event) -> [Action] {
        switch event {
        case .willShow, .didHide:
            return [.resetSearchSession, .blurSearchField]
        case .didShow:
            return [.blurSearchField, .deferredBlurSearchField]
        }
    }
}
