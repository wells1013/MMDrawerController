import AppKit
import Carbon

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var hotKeyManager: HotKeyManager!
    private var searchWindowController: SearchWindowController!
    private let appStore = AppStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. 构建应用索引（后台）
        appStore.indexApplications()

        // 2. 创建搜索窗口（默认隐藏）
        searchWindowController = SearchWindowController(appStore: appStore)

        // 3. 注册全局快捷键 ⌥ + Space（Alt/Option + Space）
        hotKeyManager = HotKeyManager()
        hotKeyManager.register(
            keyCode: UInt32(kVK_Space),
            modifiers: [.option, .command],
            handler: { [weak self] in
                self?.toggleSearchWindow()
            }
        )

        // 4. 监听系统事件（让窗口能拿到键盘焦点）
        NSApp.disableRelaunching()
    }

    func toggleSearchWindow() {
        guard let wc = searchWindowController else { return }
        if wc.isVisible {
            wc.hideWindow()
        } else {
            wc.showWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager.unregister()
    }
}
