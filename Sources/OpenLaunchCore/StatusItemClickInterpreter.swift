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

/// 状态栏右键菜单只保留维护动作，完整设置入口放在启动台内部。
public enum StatusMenuPolicy {
    public struct Item: Equatable, Sendable {
        public let title: String
        public let action: Action
    }

    public enum Action: Equatable, Sendable {
        case rescanApplications
        case quit
    }

    public static let items: [Item] = [
        Item(title: "重新扫描", action: .rescanApplications),
        Item(title: "退出", action: .quit)
    ]
}
