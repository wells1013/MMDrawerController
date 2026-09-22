import Carbon
import AppKit

// MARK: - Global HotKey Manager

/// 使用 Carbon RegisterEventHotKey 注册全局快捷键
final class HotKeyManager {

    private var hotKeyRef: EventHotKeyRef?
    private var handler: (() -> Void)?

    // 用于 C 回调的 Target
    private var eventTarget: EventTargetRef?
    private static let hotKeyID = EventHotKeyID(signature: OSType(0x514B4C4B), id: 1) // 'QKLK'

    // modifiers: 传 NSEvent.ModifierFlags
    func register(keyCode: UInt32, modifiers: NSEvent.ModifierFlags, handler: @escaping () -> Void) {
        self.handler = handler

        // 事件处理回调
        let callback: EventHandlerUPP = { _, event, refcon -> OSStatus in
            guard let refcon = refcon else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(refcon).takeUnretainedValue()
            // 需要在主线程回调
            DispatchQueue.main.async {
                manager.handler?()
            }
            return noErr
        }

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        // 构造自引用，保证生命周期
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &spec,
            selfPtr,
            &eventTarget
        )

        // Carbon 期望的 modifiers 位掩码与 NSEvent.ModifierFlags.rawValue 一致
        let carbonMods = UInt32(modifiers.rawValue)
        RegisterEventHotKey(keyCode, carbonMods, Self.hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let target = eventTarget {
            RemoveEventHandler(target)
            eventTarget = nil
        }
    }

    deinit {
        unregister()
    }
}
