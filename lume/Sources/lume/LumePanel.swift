import AppKit

// MARK: - LumePanel
// 自定义 NSPanel，解决 .nonactivatingPanel 无法成为 key window 的问题，
// 并拦截 ESC 关闭窗口。

final class LumePanel: NSPanel {

    // 让 nonactivatingPanel 也能成为 key window（收键盘事件）
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    // ESC 直接关闭
    override func keyDown(with event: NSEvent) {
        if event.keyCode == kVK_Escape {
            orderOut(nil)
            return
        }
        super.keyDown(with: event)
    }
}
