import AppKit
import Carbon
import SwiftUI

/// Apple 风格搜索输入，外层由 SwiftUI 绘制玻璃胶囊和图标。
struct SearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onEscape: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onEscape: onEscape)
    }

    func makeNSView(context: Context) -> OpenLaunchSearchField {
        let searchField = OpenLaunchSearchField()
        searchField.placeholderString = placeholder
        searchField.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: NSColor.white.withAlphaComponent(0.56)
            ]
        )
        searchField.focusRingType = .none
        searchField.isBezeled = false
        searchField.isBordered = false
        searchField.drawsBackground = false
        searchField.isEditable = true
        searchField.isSelectable = true
        searchField.font = .systemFont(ofSize: 16, weight: .regular)
        searchField.textColor = .white
        searchField.alignment = .left
        searchField.usesSingleLineMode = true
        searchField.lineBreakMode = .byTruncatingTail
        searchField.delegate = context.coordinator
        searchField.onEscape = onEscape
        searchField.configureFocusObserver()
        context.coordinator.onEscape = onEscape
        return searchField
    }

    func updateNSView(_ searchField: OpenLaunchSearchField, context: Context) {
        if searchField.stringValue != text {
            searchField.stringValue = text
        }
        searchField.onEscape = onEscape

        if searchField.isOpenLaunchFirstResponder {
            DispatchQueue.main.async {
                searchField.moveInsertionPointToEnd()
            }
        }
    }

    static func dismantleNSView(_ nsView: OpenLaunchSearchField, coordinator: Coordinator) {
        nsView.invalidateFocusObserver()
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding private var text: String
        var onEscape: () -> Void

        init(text: Binding<String>, onEscape: @escaping () -> Void) {
            _text = text
            self.onEscape = onEscape
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let searchField = notification.object as? NSTextField else {
                return
            }

            if let editor = searchField.currentEditor() as? NSTextView {
                editor.insertionPointColor = .white
            }
            text = searchField.stringValue
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            guard let searchField = notification.object as? NSTextField,
                  let editor = searchField.currentEditor() as? NSTextView else {
                return
            }

            editor.insertionPointColor = .white
            editor.selectedTextAttributes = [
                .backgroundColor: NSColor.controlAccentColor.withAlphaComponent(0.82),
                .foregroundColor: NSColor.white
            ]
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                onEscape()
                return true
            }

            return false
        }
    }
}

/// 捕获 Escape 的文本输入子类。
final class OpenLaunchSearchField: NSTextField {
    var onEscape: (() -> Void)?
    private var focusObserver: NSObjectProtocol?
    private var blurObserver: NSObjectProtocol?
    private var allowsExplicitFocus = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        cell = VerticallyCenteredTextFieldCell(textCell: "")
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        cell = VerticallyCenteredTextFieldCell(textCell: "")
    }

    override func keyDown(with event: NSEvent) {
        if Int(event.keyCode) == kVK_Escape {
            onEscape?()
            return
        }

        super.keyDown(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        focusAndMoveInsertionPointToEnd()
        super.mouseDown(with: event)
        updateInsertionPointAppearance()
    }

    override var acceptsFirstResponder: Bool {
        allowsExplicitFocus
    }

    override func becomeFirstResponder() -> Bool {
        let becameFirstResponder = super.becomeFirstResponder()
        updateInsertionPointAppearance()
        return becameFirstResponder
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    var isOpenLaunchFirstResponder: Bool {
        guard let firstResponder = window?.firstResponder else {
            return false
        }

        return firstResponder === self || firstResponder === currentEditor()
    }

    func configureFocusObserver() {
        guard focusObserver == nil else {
            return
        }

        focusObserver = NotificationCenter.default.addObserver(
            forName: .openLaunchFocusSearch,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.focusAndMoveInsertionPointToEnd()
        }

        blurObserver = NotificationCenter.default.addObserver(
            forName: .openLaunchBlurSearch,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resignOpenLaunchFocus()
        }
    }

    func invalidateFocusObserver() {
        if let focusObserver {
            NotificationCenter.default.removeObserver(focusObserver)
            self.focusObserver = nil
        }
        if let blurObserver {
            NotificationCenter.default.removeObserver(blurObserver)
            self.blurObserver = nil
        }
    }

    func moveInsertionPointToEnd() {
        currentEditor()?.selectedRange = NSRange(location: stringValue.count, length: 0)
        updateInsertionPointAppearance()
    }

    private func focusAndMoveInsertionPointToEnd() {
        allowsExplicitFocus = true
        window?.makeFirstResponder(self)
        moveInsertionPointToEnd()
    }

    private func resignOpenLaunchFocus() {
        allowsExplicitFocus = false
        abortEditing()
        if isOpenLaunchFirstResponder {
            window?.makeFirstResponder(nil)
        }
    }

    private func updateInsertionPointAppearance() {
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  let editor = self.currentEditor() as? NSTextView else {
                return
            }

            editor.insertionPointColor = .white
        }
    }
}

/// 让单行搜索文字在玻璃胶囊中与放大镜图标保持视觉居中。
final class VerticallyCenteredTextFieldCell: NSTextFieldCell {
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        var drawingRect = super.drawingRect(forBounds: rect)
        let textHeight = cellSize(forBounds: rect).height
        drawingRect.origin.y += max((rect.height - textHeight) / 2 - 1, 0)
        drawingRect.size.height = textHeight
        return drawingRect
    }

    override func edit(
        withFrame rect: NSRect,
        in controlView: NSView,
        editor textObj: NSText,
        delegate: Any?,
        event: NSEvent?
    ) {
        super.edit(
            withFrame: drawingRect(forBounds: rect),
            in: controlView,
            editor: textObj,
            delegate: delegate,
            event: event
        )
    }

    override func select(
        withFrame rect: NSRect,
        in controlView: NSView,
        editor textObj: NSText,
        delegate: Any?,
        start selStart: Int,
        length selLength: Int
    ) {
        super.select(
            withFrame: drawingRect(forBounds: rect),
            in: controlView,
            editor: textObj,
            delegate: delegate,
            start: selStart,
            length: selLength
        )
    }
}
