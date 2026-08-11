import Foundation

public enum RcloneExcludeFileMode: String, Sendable {
    case sync
    case check
}

public protocol RcloneExcludeFilePreparing: Sendable {
    func prepareExcludeFile(for pair: SyncPair, mode: RcloneExcludeFileMode) throws -> String?
}

public struct PersistentRcloneExcludeFileStore: RcloneExcludeFilePreparing, @unchecked Sendable {
    private let paths: AppPaths
    private let fileManager: FileManager

    public init(paths: AppPaths, fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
    }

    public func prepareExcludeFile(for pair: SyncPair, mode: RcloneExcludeFileMode) throws -> String? {
        let patterns = normalizedPatterns(for: pair, mode: mode)
        guard !patterns.isEmpty else {
            return nil
        }

        try fileManager.createDirectory(at: paths.rcloneFiltersDirectory, withIntermediateDirectories: true, attributes: nil)

        let fileURL = paths.rcloneFiltersDirectory
            .appendingPathComponent(pair.id.uuidString, isDirectory: false)
            .appendingPathExtension(mode.rawValue)
            .appendingPathExtension("txt")

        try (patterns.joined(separator: "\n") + "\n").write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL.path
    }

    private func normalizedPatterns(for pair: SyncPair, mode: RcloneExcludeFileMode) -> [String] {
        let sourcePatterns: [String]
        switch mode {
        case .sync:
            sourcePatterns = pair.allSyncExcludes
        case .check:
            sourcePatterns = pair.allCheckExcludes
        }

        let basePatterns = sourcePatterns
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var seen = Set<String>()
        var expandedPatterns: [String] = []

        for pattern in basePatterns {
            if seen.insert(pattern).inserted {
                expandedPatterns.append(pattern)
            }

            guard shouldExpandRecursively(pattern) else {
                continue
            }

            let recursivePattern = "\(pattern)/**"
            if seen.insert(recursivePattern).inserted {
                expandedPatterns.append(recursivePattern)
            }
        }

        return expandedPatterns
    }

    private func shouldExpandRecursively(_ pattern: String) -> Bool {
        !pattern.hasSuffix("/**")
            && !pattern.contains("/")
            && !pattern.contains("*")
            && !pattern.contains("?")
    }
}
