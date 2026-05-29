import Foundation

struct RcloneExcludeMatcher {
    private let patterns: [String]

    init(patterns: [String]) {
        var seen = Set<String>()
        self.patterns = patterns
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
    }

    func matches(relativePath: String, isDirectory: Bool) -> Bool {
        let normalizedPath = normalizePath(relativePath)
        let basename = URL(fileURLWithPath: normalizedPath).lastPathComponent
        let pathComponents = normalizedPath.split(separator: "/").map(String.init)

        for pattern in patterns {
            if isLiteralDirectoryPattern(pattern),
               pathComponents.contains(normalizePath(pattern)) {
                return true
            }

            if pattern.hasSuffix("/**") {
                let directoryPattern = String(pattern.dropLast(3))
                let normalizedDirectoryPattern = normalizePath(directoryPattern)

                if normalizedPath == normalizedDirectoryPattern
                    || normalizedPath.hasPrefix("\(normalizedDirectoryPattern)/")
                    || normalizedPath.hasSuffix("/\(normalizedDirectoryPattern)")
                    || normalizedPath.contains("/\(normalizedDirectoryPattern)/") {
                    return true
                }

                continue
            }

            if pattern.contains("/") {
                if matchesLike(pattern: pattern, value: normalizedPath)
                    || normalizedPath.hasSuffix("/\(pattern)") {
                    return true
                }
                continue
            }

            if basename == pattern || matchesLike(pattern: pattern, value: basename) {
                return true
            }
        }

        if isDirectory {
            return patterns.contains { pattern in
                pattern == "\(basename)/**"
            }
        }

        return false
    }

    private func isLiteralDirectoryPattern(_ pattern: String) -> Bool {
        !pattern.hasSuffix("/**")
            && !pattern.contains("/")
            && !pattern.contains("*")
            && !pattern.contains("?")
    }

    private func matchesLike(pattern: String, value: String) -> Bool {
        let escapedPattern = NSRegularExpression.escapedPattern(for: pattern)
            .replacingOccurrences(of: "\\*", with: ".*")
            .replacingOccurrences(of: "\\?", with: ".")
        let regex = "^\(escapedPattern)$"

        guard let expression = try? NSRegularExpression(pattern: regex) else {
            return false
        }

        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return expression.firstMatch(in: value, options: [], range: range) != nil
    }

    private func normalizePath(_ path: String) -> String {
        path
            .replacingOccurrences(of: "\\", with: "/")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
