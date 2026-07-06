import Foundation

extension Notification.Name {
    /// 要求主界面把键盘焦点移动到搜索框。
    static let openLaunchFocusSearch = Notification.Name("OpenLaunchFocusSearch")

    /// 要求主界面释放搜索框焦点，避免再次进入时残留插入光标。
    static let openLaunchBlurSearch = Notification.Name("OpenLaunchBlurSearch")

    /// 覆盖层已经隐藏，要求 AppDelegate 恢复菜单栏入口和系统栏状态。
    static let openLaunchDidHide = Notification.Name("OpenLaunchDidHide")
}
