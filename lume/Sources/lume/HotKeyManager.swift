import Carbon
import AppKit

// MARK: - Global HotKey Manager

final class HotKeyManager {

    private var hotKeyRef: EventHotKeyRef?
    private var handler: (() -> Void)?
    private var eventTarget: EventTargetRef?
    private static let hotKeyID = EventHotKeyID(signature: OSType(0x514B4C4B), id: 1)

    func register(keyCode: UInt32, modifiers: NSEvent.ModifierFlags, handler: @escaping () -> Void) {
        self.handler = handler

        let callback: EventHandlerUPP = { _, event, refcon -> OSStatus in
            guard let refcon = refcon else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(refcon).takeUnretainedValue()
            DispatchQueue.main.async { manager.handler?() }
            return noErr
        }

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            callback, 1, &spec, selfPtr, &eventTarget
        )

        RegisterEventHotKey(keyCode, UInt32(modifiers.rawValue),
                            Self.hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let ref = hotKeyRef   { UnregisterEventHotKey(ref); hotKeyRef = nil }
        if let tgt = eventTarget { RemoveEventHandler(tgt); eventTarget = nil }
    }

    deinit { unregister() }
}

