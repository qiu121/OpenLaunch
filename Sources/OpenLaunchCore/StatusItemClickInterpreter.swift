/// 状态栏图标点击行为：主点击进入 OpenLaunch，辅助点击展示菜单。
public enum StatusItemClickInterpreter {
    public enum Action: Equatable {
        case showLauncher
        case showMenu
    }

    public static func action(isSecondaryClick: Bool, isControlPressed: Bool) -> Action {
        isSecondaryClick || isControlPressed ? .showMenu : .showLauncher
    }
}
