import Foundation

/// Where a pair's local folder stands right now. Only `.missing` and `.moved`
/// are worth a warning; `.unknown` exists so that a permission problem is never
/// reported as a missing folder.
public enum LocalFolderStatus: Equatable, Sendable {
    case available
    case unknown
    /// The bookmark resolves to a different, existing folder. `bookmark` is a
    /// fresh bookmark for it, ready to be stored if the user accepts the move.
    case moved(path: String, bookmark: Data)
    case missing

    public var needsAttention: Bool {
        switch self {
        case .moved, .missing: true
        case .available, .unknown: false
        }
    }
}

public enum PathExistence: Equatable, Sendable {
    case exists
    /// The system said "no such file" — not a permission error.
    case absent
    case unknown
}

public enum BookmarkResolution: Equatable, Sendable {
    case unresolvable
    case resolved(path: String, existence: PathExistence, freshBookmark: Data?)
}

public protocol LocalFolderBookmarkResolving: Sendable {
    func resolve(bookmark: Data, storedPath: String) -> BookmarkResolution
}

public protocol LocalPathProbing: Sendable {
    func existence(atPath path: String) -> PathExistence
}

public protocol LocalFolderAvailabilityChecking: Sendable {
    func status(of pair: SyncPair) -> LocalFolderStatus
}

/// Everything is "available": used where the paths are invented (UI-test
/// seeds) and as the `SyncService` default so existing callers are unchanged.
public struct NoopLocalFolderAvailabilityChecker: LocalFolderAvailabilityChecking {
    public init() {}

    public func status(of pair: SyncPair) -> LocalFolderStatus { .available }
}

public struct LocalFolderAvailabilityChecker: LocalFolderAvailabilityChecking {
    private let resolver: LocalFolderBookmarkResolving
    private let prober: LocalPathProbing

    public init(resolver: LocalFolderBookmarkResolving, prober: LocalPathProbing) {
        self.resolver = resolver
        self.prober = prober
    }

    public func status(of pair: SyncPair) -> LocalFolderStatus {
        let storedPath = pair.localFolderDisplayPath

        if !pair.localFolderBookmark.isEmpty,
           case let .resolved(resolvedPath, existence, freshBookmark) = resolver.resolve(
               bookmark: pair.localFolderBookmark,
               storedPath: storedPath
           ) {
            switch existence {
            case .exists:
                if Self.samePath(resolvedPath, storedPath) {
                    return .available
                }
                // A bookmark follows a folder into the Trash; offering that as the new path would be wrong.
                if resolvedPath.split(separator: "/").contains(".Trash") {
                    return .missing
                }
                // No bookmark to store means we cannot offer the move; the
                // folder is still not where the pair says it is.
                guard let freshBookmark else { return .missing }
                return .moved(path: resolvedPath, bookmark: freshBookmark)
            case .absent:
                return .missing
            case .unknown:
                return .unknown
            }
        }

        // No bookmark, or it no longer resolves: judge the stored path alone.
        switch prober.existence(atPath: storedPath) {
        case .exists: return .available
        case .absent: return .missing
        case .unknown: return .unknown
        }
    }

    static func samePath(_ lhs: String, _ rhs: String) -> Bool {
        func normalized(_ path: String) -> String {
            URL(fileURLWithPath: path, isDirectory: true).resolvingSymlinksInPath().standardizedFileURL.path
        }
        return normalized(lhs) == normalized(rhs)
    }
}
