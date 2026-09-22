import AppKit
import Carbon

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var hotKeyManager: HotKeyManager!
    private var searchWindowController: SearchWindowController!
    private let appStore = AppStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        appStore.indexApplications()
        searchWindowController = SearchWindowController(appStore: appStore)
        hotKeyManager = HotKeyManager()
        hotKeyManager.register(
            keyCode: UInt32(kVK_Space),
            modifiers: [.option, .command],
            handler: { [weak self] in
                self?.toggleSearchWindow()
            }
        )
    }

    func toggleSearchWindow() {
        guard let wc = searchWindowController else { return }
        if wc.isVisible { wc.hideWindow() } else { wc.showWindow() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager.unregister()
    }
}

