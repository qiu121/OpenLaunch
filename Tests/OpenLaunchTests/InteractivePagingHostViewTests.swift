import AppKit
import SwiftUI
import XCTest
@testable import OpenLaunch

@MainActor
final class InteractivePagingHostViewTests: XCTestCase {
    func testVisibleSecondPageReceivesPointerHitTesting() {
        let firstPageButton = NSButton(title: "第一页", target: nil, action: nil)
        let secondPageButton = NSButton(title: "第二页", target: nil, action: nil)
        let pageSize = CGSize(width: 320, height: 180)
        let pageSpacing: CGFloat = 24
        let rootView = HStack(spacing: 0) {
            TestButtonView(button: firstPageButton)
                .frame(width: pageSize.width, height: pageSize.height)
                .padding(.trailing, pageSpacing)
            TestButtonView(button: secondPageButton)
                .frame(width: pageSize.width, height: pageSize.height)
        }
        .frame(
            width: pageSize.width * 2 + pageSpacing,
            height: pageSize.height,
            alignment: .leading
        )

        let hostView = InteractivePagingHostView(rootView: AnyView(rootView))
        hostView.frame = NSRect(origin: .zero, size: pageSize)
        hostView.update(
            rootView: AnyView(rootView),
            currentPage: 1,
            pageCount: 2,
            pageSpacing: pageSpacing,
            onPageChanged: { _ in }
        )
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: pageSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostView
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        hostView.layoutSubtreeIfNeeded()

        let hitView = hostView.hitTest(NSPoint(x: pageSize.width / 2, y: pageSize.height / 2))
        let trackView = hostView.subviews.first
        let diagnostic = "命中视图：\(String(describing: hitView))；"
            + "轨道 frame：\(String(describing: trackView?.frame))；"
            + "轨道 bounds：\(String(describing: trackView?.bounds))"

        XCTAssertTrue(hitView === secondPageButton, diagnostic)
        XCTAssertFalse(hitView === firstPageButton)
    }
}

private struct TestButtonView: NSViewRepresentable {
    let button: NSButton

    func makeNSView(context: Context) -> NSButton {
        button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {}
}
