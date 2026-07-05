import Carbon
import Foundation

/// 使用 Carbon 注册一个全局快捷键；当前 MVP 默认使用 Control-Option-Command-L。
final class HotkeyManager {
    private var eventHotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let hotkeyID: EventHotKeyID
    private let onPressed: () -> Void

    init(keyCode: UInt32, modifiers: UInt32, id: UInt32 = 1, onPressed: @escaping () -> Void) {
        self.hotkeyID = EventHotKeyID(signature: HotkeyManager.fourCharacterCode("OLCH"), id: id)
        self.onPressed = onPressed
        installHandler()
        registerHotkey(keyCode: keyCode, modifiers: modifiers)
    }

    deinit {
        if let eventHotKeyRef {
            UnregisterEventHotKey(eventHotKeyRef)
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    private func installHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else {
                    return noErr
                }

                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                var hotkeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotkeyID
                )

                if hotkeyID.signature == manager.hotkeyID.signature && hotkeyID.id == manager.hotkeyID.id {
                    manager.onPressed()
                }

                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandlerRef
        )
    }

    private func registerHotkey(keyCode: UInt32, modifiers: UInt32) {
        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &eventHotKeyRef
        )
    }

    private static func fourCharacterCode(_ string: String) -> OSType {
        string.utf8.reduce(0) { result, character in
            (result << 8) + OSType(character)
        }
    }
}
