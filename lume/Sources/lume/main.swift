import AppKit

// MARK: - Application Entry

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// 后台应用：不显示在 Dock 和 Command-Tab 中
app.setActivationPolicy(.accessory)
app.run()
