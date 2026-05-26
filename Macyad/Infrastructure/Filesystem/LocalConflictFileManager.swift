import Foundation

public protocol LocalConflictFileManaging: Sendable {
    func makeConflictCopy(for pair: SyncPair, relativePath: String, at date: Date) throws -> URL
    func removeCanonicalLocalItem(for pair: SyncPair, relativePath: String) throws
    func canonicalLocalURL(for pair: SyncPair, relativePath: String) -> URL
}

public struct LocalConflictFileManager: LocalConflictFileManaging, @unchecked Sendable {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func makeConflictCopy(for pair: SyncPair, relativePath: String, at date: Date) throws -> URL {
        let originalURL = canonicalLocalURL(for: pair, relativePath: relativePath)
        let destinationURL = conflictCopyURL(for: pair, relativePath: relativePath, at: date)

        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: originalURL, to: destinationURL)
        return destinationURL
    }

    public func removeCanonicalLocalItem(for pair: SyncPair, relativePath: String) throws {
        let url = canonicalLocalURL(for: pair, relativePath: relativePath)
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        try fileManager.removeItem(at: url)
    }

    public func canonicalLocalURL(for pair: SyncPair, relativePath: String) -> URL {
        URL(fileURLWithPath: pair.localFolderDisplayPath, isDirectory: true).appending(path: relativePath)
    }

    public func conflictCopyURL(for pair: SyncPair, relativePath: String, at date: Date) -> URL {
        let originalURL = canonicalLocalURL(for: pair, relativePath: relativePath)
        let formattedDate = Self.conflictDateFormatter.string(from: date)
        let extensionPart = originalURL.pathExtension
        let baseName = originalURL.deletingPathExtension().lastPathComponent
        let conflictName = extensionPart.isEmpty
            ? "\(baseName) (MacYaD conflict \(formattedDate))"
            : "\(baseName) (MacYaD conflict \(formattedDate)).\(extensionPart)"

        return originalURL.deletingLastPathComponent().appending(path: conflictName)
    }

    private static let conflictDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        return formatter
    }()
}
