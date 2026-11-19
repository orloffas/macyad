import Foundation

/// Resolves a pair's stored bookmark. The app is not sandboxed, so the bookmarks
/// made by the folder picker are plain (`.minimalBookmark`), not security-scoped;
/// resolving them needs no scope option. Scoped access is still opened around the
/// check, which is a harmless no-op for plain bookmarks and keeps scoped ones
/// (older or imported) working.
public struct BookmarkFolderResolver: LocalFolderBookmarkResolving {
    private let prober: LocalPathProbing

    public init(prober: LocalPathProbing = POSIXPathProber()) {
        self.prober = prober
    }

    public func resolve(bookmark: Data, storedPath: String) -> BookmarkResolution {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withoutUI, .withoutMounting],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return .unresolvable
        }

        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess { url.stopAccessingSecurityScopedResource() }
        }

        let existence = prober.existence(atPath: url.path)
        var fresh: Data?
        if existence == .exists, isStale || url.path != storedPath {
            fresh = try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        return .resolved(path: url.path, existence: existence, freshBookmark: fresh)
    }
}

/// `stat` rather than `FileManager.fileExists`: only ENOENT/ENOTDIR count as
/// "absent". A permission error stays `.unknown` so TCC never produces a false
/// "missing".
public struct POSIXPathProber: LocalPathProbing {
    public init() {}

    public func existence(atPath path: String) -> PathExistence {
        var info = stat()
        if stat(path, &info) == 0 {
            return (info.st_mode & S_IFMT) == S_IFDIR ? .exists : .absent
        }
        return errno == ENOENT || errno == ENOTDIR ? .absent : .unknown
    }
}
