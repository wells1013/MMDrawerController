import AppKit
import Foundation

// MARK: - AppInfo

enum AppSource {
    case applications      // /Applications 或 ~/Applications
    case systemUtilities   // /System/Applications/Utilities
    case custom(String)    // 自定义路径
}

struct AppInfo {
    let name: String
    let path: String
    let bundleID: String?
    let icon: NSImage?
    let source: AppSource

    // 用于搜索：lowercased + 移除空格
    let searchableName: String
}

// MARK: - AppStore

/// 扫描系统中所有 .app 应用
final class AppStore {

    private(set) var apps: [AppInfo] = []
    private let fileManager = FileManager.default
    private let lock = NSLock()

    /// 加锁读取 apps 副本，避免并发读写
    func snapshot() -> [AppInfo] {
        lock.lock()
        defer { lock.unlock() }
        return apps
    }

    func indexApplications() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var discovered: [AppInfo] = []
            let searchPaths: [(String, AppSource)] = [
                ("/Applications", .applications),
                ("\(NSHomeDirectory())/Applications", .applications),
                ("/System/Applications", .applications),
                ("/System/Applications/Utilities", .systemUtilities),
            ]

            for (dir, source) in searchPaths {
                self.scanDirectory(dir: dir, source: source, into: &discovered)
            }

            // 去重（按 name），优先保留 /Applications 里的
            var seen = Set<String>()
            var deduped: [AppInfo] = []
            for app in discovered.sorted(by: { $0.source.priority > $1.source.priority }) {
                if seen.insert(app.searchableName).inserted {
                    deduped.append(app)
                }
            }

            self.lock.lock()
            self.apps = deduped
            self.lock.unlock()
        }
    }

    private func scanDirectory(dir: String, source: AppSource, into list: inout [AppInfo]) {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: dir, isDirectory: &isDir), isDir.boolValue else { return }

        do {
            let contents = try fileManager.contentsOfDirectory(
                atPath: dir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            for url in contents {
                guard url.pathExtension == "app" else { continue }
                if let info = buildAppInfo(from: url, source: source) {
                    list.append(info)
                }
            }
        } catch {
            // 忽略无权限的目录
        }
    }

    private func buildAppInfo(from url: URL, source: AppSource) -> AppInfo? {
        let path = url.path
        let name = url.deletingPathExtension().lastPathComponent
        let searchableName = name
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: "")

        // 获取 bundle ID
        let bundle = Bundle(url: url)
        let bundleID = bundle?.bundleIdentifier

        // 获取图标（用 NSWorkspace）
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon?.size = NSSize(width: 32, height: 32)

        return AppInfo(
            name: name,
            path: path,
            bundleID: bundleID,
            icon: icon,
            source: source,
            searchableName: searchableName
        )
    }
}

extension AppSource {
    var priority: Int {
        switch self {
        case .applications: return 3
        case .systemUtilities: return 2
        case .custom: return 1
        }
    }
}

