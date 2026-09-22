import AppKit

// MARK: - SearchWindowController
// Spotlight 风格的悬浮搜索窗口

final class SearchWindowController: NSWindowController, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {

    private let appStore: AppStore
    private let fuzzyMatcher = FuzzyMatcher()

    private var results: [AppInfo] = []
    private var selectedIndex: Int = 0

    // UI 组件
    private let searchField = NSTextField()
    private let resultTable = NSTableView()
    private let scrollView = NSScrollView()
    private let visualView = NSVisualEffectView()

    // 窗口尺寸
    private let windowWidth: CGFloat = 520
    private let windowHeight: CGFloat = 420
    private let baseHeight: CGFloat = 120   // 只有输入框时的高度
    private let maxResults = 8

    init(appStore: AppStore) {
        self.appStore = appStore

        // 创建无边框悬浮窗口（保留 .nonactivatingPanel 但后续主动激活 app）
        let panel = LumePanel(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: baseHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.contentView?.wantsLayer = true

        super.init(window: panel)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true

        // 背景材质（类似 Spotlight 的毛玻璃）
        visualView.material = .hudWindow
        visualView.blendingMode = .behindWindow
        visualView.state = .active
        visualView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(visualView)

        // 搜索输入框
        searchField.isBordered = false
        searchField.drawsBackground = false
        searchField.focusRingType = .none
        searchField.font = NSFont.systemFont(ofSize: 22, weight: .medium)
        searchField.placeholderString = "搜索应用…"
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(searchField)

        // 结果列表
        resultTable.frame = NSRect(x: 0, y: 0, width: windowWidth - 20, height: 300)
        resultTable.rowHeight = 36
        resultTable.headerView = nil
        resultTable.focusRingType = .none
        resultTable.backgroundColor = .clear
        resultTable.gridStyleMask = []
        resultTable.allowsMultipleSelection = false
        resultTable.dataSource = self
        resultTable.delegate = self
        resultTable.translatesAutoresizingMaskIntoConstraints = false

        // 添加一列（图标 + 名称）
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        column.title = "App"
        column.width = windowWidth - 40
        resultTable.addTableColumn(column)

        scrollView.documentView = resultTable
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.verticalScrollElasticity = .none
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(scrollView)

        // 圆角
        contentView.layer?.cornerRadius = 12
        contentView.layer?.masksToBounds = true

        // 约束
        NSLayoutConstraint.activate([
            visualView.topAnchor.constraint(equalTo: contentView.topAnchor),
            visualView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            visualView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            visualView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            searchField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            searchField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            searchField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
        ])
    }

    // MARK: - Public

    func showWindow() {
        // 重置
        searchField.stringValue = ""
        results = []
        selectedIndex = 0
        resultTable.reloadData()
        updateWindowHeight()

        // 居中到屏幕
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let w = windowWidth
            let h = baseHeight
            let x = screenFrame.midX - w / 2
            let y = screenFrame.midY + screenFrame.height * 0.15
            window?.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
        }

        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()

        // 激活 app 并聚焦输入框
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async { [weak self] in
            self?.window?.makeFirstResponder(self?.searchField)
        }
    }

    func hideWindow() {
        window?.orderOut(nil)
    }

    private func updateWindowHeight() {
        let resultHeight = CGFloat(results.count) * resultTable.rowHeight
        let newHeight = min(baseHeight + resultHeight, windowHeight)
        guard let window = window else { return }
        let frame = window.frame
        let delta = newHeight - frame.height
        window.setFrame(
            NSRect(x: frame.origin.x, y: frame.origin.y - delta, width: frame.width, height: newHeight),
            display: true
        )
        scrollView.isHidden = results.isEmpty
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let apps = appStore.snapshot()
        results = fuzzyMatcher.match(query: query, in: apps, limit: maxResults)
        selectedIndex = results.isEmpty ? 0 : 0
        resultTable.reloadData()
        updateWindowHeight()
        if !results.isEmpty {
            resultTable.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    // 拦截回车键、上下键、ESC
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.moveUp(_:)):
            moveSelectionUp()
            return true
        case #selector(NSResponder.moveDown(_:)):
            moveSelectionDown()
            return true
        case #selector(NSResponder.insertNewline(_:)):
            launchSelectedApp()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            hideWindow()
            return true
        default:
            return false
        }
    }

    private func moveSelectionUp() {
        guard !results.isEmpty else { return }
        selectedIndex = max(0, selectedIndex - 1)
        resultTable.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
    }

    private func moveSelectionDown() {
        guard !results.isEmpty else { return }
        selectedIndex = min(results.count - 1, selectedIndex + 1)
        resultTable.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
    }

    private func launchSelectedApp() {
        guard selectedIndex < results.count else { return }
        let app = results[selectedIndex]
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [app.path]
        try? task.run()
        hideWindow()
    }

    // MARK: - NSTableView DataSource & Delegate

    func numberOfRows(in tableView: NSTableView) -> Int {
        return results.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("appCell")
        var cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
        if cell == nil {
            cell = makeAppCell()
        }

        let app = results[row]
        if let helper = cell?.objectValue as? CellHelper {
            helper.iconView.image = app.icon
            helper.nameLabel.stringValue = app.name
            helper.subtitleLabel.stringValue = (app.source == .applications) ? "应用程序" : app.path
        }
        return cell
    }

    private func makeAppCell() -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = NSUserInterfaceItemIdentifier("appCell")
        let helper = CellHelper()
        cell.objectValue = helper

        let iconView = NSImageView()
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(iconView)
        helper.iconView = iconView
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
            iconView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
        ])

        let nameLabel = NSTextField(labelWithString: "")
        nameLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(nameLabel)
        helper.nameLabel = nameLabel
        cell.textField = nameLabel
        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            nameLabel.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
        ])

        let subtitleLabel = NSTextField(labelWithString: "")
        subtitleLabel.font = NSFont.systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(subtitleLabel)
        helper.subtitleLabel = subtitleLabel
        NSLayoutConstraint.activate([
            subtitleLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 0),
            subtitleLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
        ])

        return cell
    }

    // 辅助类：持有 cell 中子视图的强引用
    private final class CellHelper {
        var iconView: NSImageView!
        var nameLabel: NSTextField!
        var subtitleLabel: NSTextField!
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        selectedIndex = resultTable.selectedRow
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        selectedIndex = row
        return true
    }
}

