import Foundation

public protocol LocalFolderInspecting: Sendable {
    func containsUserVisibleContent(atPath path: String) throws -> Bool
    func containsUserVisibleContent(atPath path: String, excludedPatterns: [String]) throws -> Bool
}

public extension LocalFolderInspecting {
    func containsUserVisibleContent(atPath path: String) throws -> Bool {
        try containsUserVisibleContent(atPath: path, excludedPatterns: [])
    }
}

public struct FileManagerLocalFolderInspector: LocalFolderInspecting {
    public init() {}

    public func containsUserVisibleContent(atPath path: String, excludedPatterns: [String]) throws -> Bool {
        let rootURL = URL(fileURLWithPath: path, isDirectory: true).resolvingSymlinksInPath()
        let matcher = RcloneExcludeMatcher(patterns: excludedPatterns)

        return try directoryContainsUserVisibleContent(
            at: rootURL,
            rootURL: rootURL,
            matcher: matcher,
            isTopLevel: true
        )
    }

    private func directoryContainsUserVisibleContent(
        at directoryURL: URL,
        rootURL: URL,
        matcher: RcloneExcludeMatcher,
        isTopLevel: Bool
    ) throws -> Bool {
        let items = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsPackageDescendants]
        )

        for itemURL in items {
            let resourceValues = try itemURL.resourceValues(forKeys: [.isDirectoryKey])
            let isDirectory = resourceValues.isDirectory ?? false
            let resolvedItemURL = itemURL.resolvingSymlinksInPath()
            let relativePath = relativePath(for: resolvedItemURL, rootURL: rootURL)
            let pathComponents = relativePath.split(separator: "/").map(String.init)

            if isTopLevel && itemURL.lastPathComponent.hasPrefix(".") {
                continue
            }

            if pathComponents.contains(where: { $0.hasPrefix(".") }) {
                continue
            }

            if matcher.matches(relativePath: relativePath, isDirectory: isDirectory) {
                continue
            }

            if isDirectory {
                if try directoryContainsUserVisibleContent(
                    at: itemURL,
                    rootURL: rootURL,
                    matcher: matcher,
                    isTopLevel: false
                ) {
                    return true
                }
            } else {
                return true
            }
        }

        return false
    }

    private func relativePath(for itemURL: URL, rootURL: URL) -> String {
        let rootComponents = rootURL.pathComponents
        let itemComponents = itemURL.pathComponents

        guard itemComponents.starts(with: rootComponents) else {
            return itemURL.lastPathComponent
        }

        return itemComponents
            .dropFirst(rootComponents.count)
            .joined(separator: "/")
    }
}
