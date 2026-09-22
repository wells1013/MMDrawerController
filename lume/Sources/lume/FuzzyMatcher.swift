import Foundation

// MARK: - FuzzyMatcher
// 轻量级模糊匹配：支持子串匹配 + 分数排序

final class FuzzyMatcher {

    /// 对 apps 进行模糊搜索，返回 top N 结果
    func match(query: String, in apps: [AppInfo], limit: Int) -> [AppInfo] {
        let q = query.lowercased().replacingOccurrences(of: " ", with: "")

        if q.isEmpty {
            return Array(apps.prefix(limit))
        }

        var scored: [(AppInfo, Int)] = []
        for app in apps {
            if let score = computeScore(query: q, target: app.searchableName) {
                scored.append((app, score))
            }
        }

        // 分数越高越靠前
        scored.sort { $0.1 > $1.1 }
        return scored.prefix(limit).map { $0.0 }
    }

    /// 返回匹配分数；nil 表示不匹配
    private func computeScore(query: String, target: String) -> Int? {
        // 1. 完全匹配
        if target == query {
            return 10_000
        }

        // 2. 前缀匹配（高权重）
        if target.hasPrefix(query) {
            return 8_000 + (1_000 - target.count) // 越短越靠前
        }

        // 3. 包含匹配（中权重）
        if target.contains(query) {
            // 位置越靠前分数越高
            if let range = target.range(of: query) {
                let pos = target.distance(from: target.startIndex, to: range.lowerBound)
                return 6_000 + (500 - pos * 10)
            }
        }

        // 4. 逐字符子序列匹配（Low priority but still valid）
        if isSubsequence(query: query, target: target) {
            return 3_000 + (500 - target.count / 2)
        }

        return nil
    }

    /// 判断 query 是否是 target 的子序列（字符按顺序出现但不要求连续）
    private func isSubsequence(query: String, target: String) -> Bool {
        let qChars = Array(query)
        let tChars = Array(target)
        var qi = 0
        for tc in tChars {
            if qi < qChars.count && qChars[qi] == tc {
                qi += 1
            }
        }
        return qi == qChars.count
    }
}

