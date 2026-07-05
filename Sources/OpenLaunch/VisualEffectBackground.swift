import AppKit
import SwiftUI

/// 使用 AppKit 的系统视觉效果视图呈现当前桌面背景的模糊材质。
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .fullScreenUI
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = false
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = .fullScreenUI
        view.blendingMode = .behindWindow
        view.state = .active
    }
}
