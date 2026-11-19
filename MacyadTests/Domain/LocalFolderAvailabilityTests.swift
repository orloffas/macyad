import Foundation
import XCTest
@testable import MacyadCore

final class LocalFolderAvailabilityTests: XCTestCase {
    private struct FakeResolver: LocalFolderBookmarkResolving {
        var result: BookmarkResolution
        func resolve(bookmark: Data, storedPath: String) -> BookmarkResolution { result }
    }

    private struct FakeProber: LocalPathProbing {
        var result: PathExistence
        func existence(atPath path: String) -> PathExistence { result }
    }

    private struct AlwaysMissing: LocalFolderAvailabilityChecking {
        func status(of pair: SyncPair) -> LocalFolderStatus { .missing }
    }

    /// Any rclone call fails, so an `.alarm` outcome would mean rclone was reached.
    private struct UnreachableProcessClient: RcloneProcessRunning {
        struct Reached: Error {}
        func run(_ arguments: [String]) async throws -> (stdout: String, stderr: String, exitCode: Int32) {
            throw Reached()
        }
        func runStreaming(_ arguments: [String]) async throws -> RcloneStreamingHandle {
            throw Reached()
        }
    }

    private let storedPath = "/Users/test/Documents/Project"
    private let freshBookmark = Data("fresh".utf8)

    private func makePair(bookmark: Data = Data("old".utf8)) -> SyncPair {
        SyncPair(
            id: UUID(),
            name: "Project",
            localFolderBookmark: bookmark,
            localFolderDisplayPath: storedPath,
            remotePath: "yandex:Project",
            scheduleMinutes: 15,
            deletePolicy: .mirrorToYandex,
            lastKnownSeverity: .healthy
        )
    }

    private func status(
        resolution: BookmarkResolution,
        stored: PathExistence = .unknown,
        pair: SyncPair? = nil
    ) -> LocalFolderStatus {
        LocalFolderAvailabilityChecker(
            resolver: FakeResolver(result: resolution),
            prober: FakeProber(result: stored)
        ).status(of: pair ?? makePair())
    }

    func testBookmarkResolvingToSamePathIsAvailable() {
        XCTAssertEqual(status(resolution: .resolved(path: storedPath, existence: .exists, freshBookmark: nil)), .available)
    }

    func testBookmarkResolvingToDifferentExistingPathIsMoved() {
        let newPath = "/Users/test/Archive/Project"
        XCTAssertEqual(
            status(resolution: .resolved(path: newPath, existence: .exists, freshBookmark: freshBookmark)),
            .moved(path: newPath, bookmark: freshBookmark)
        )
    }

    func testFolderMovedToTrashIsMissingNotMoved() {
        let trashed = "/Users/test/.Trash/Work Docs"
        XCTAssertEqual(
            status(resolution: .resolved(path: trashed, existence: .exists, freshBookmark: Data("fresh".utf8))),
            .missing
        )
    }

    func testFolderInExternalVolumeTrashesIsMissingNotMoved() {
        XCTAssertEqual(
            status(resolution: .resolved(path: "/Volumes/Backup/.Trashes/501/Work Docs", existence: .exists, freshBookmark: Data("fresh".utf8))),
            .missing
        )
    }

    func testResolvedPathThatDoesNotExistIsMissing() {
        XCTAssertEqual(status(resolution: .resolved(path: storedPath, existence: .absent, freshBookmark: nil)), .missing)
    }

    func testResolvedPathWithUnknownExistenceIsNotReportedMissing() {
        XCTAssertEqual(status(resolution: .resolved(path: storedPath, existence: .unknown, freshBookmark: nil)), .unknown)
    }

    func testUnresolvableBookmarkFallsBackToStoredPath() {
        XCTAssertEqual(status(resolution: .unresolvable, stored: .absent), .missing)
        XCTAssertEqual(status(resolution: .unresolvable, stored: .exists), .available)
        XCTAssertEqual(status(resolution: .unresolvable, stored: .unknown), .unknown)
    }

    func testPairWithoutBookmarkUsesStoredPathAndKeepsPermissionErrorsUnknown() {
        let pair = makePair(bookmark: Data())
        // The resolver result must be ignored when there is no bookmark.
        let ignored = BookmarkResolution.resolved(path: "/Users/test/Elsewhere", existence: .exists, freshBookmark: freshBookmark)
        XCTAssertEqual(status(resolution: ignored, stored: .exists, pair: pair), .available)
        XCTAssertEqual(status(resolution: ignored, stored: .absent, pair: pair), .missing)
        XCTAssertEqual(status(resolution: ignored, stored: .unknown, pair: pair), .unknown)
    }

    func testSamePathIgnoresTrailingSlash() {
        XCTAssertEqual(status(resolution: .resolved(path: storedPath + "/", existence: .exists, freshBookmark: nil)), .available)
    }

    func testNeedsAttentionOnlyForMissingAndMoved() {
        XCTAssertTrue(LocalFolderStatus.missing.needsAttention)
        XCTAssertTrue(LocalFolderStatus.moved(path: "/Users/test/x", bookmark: Data()).needsAttention)
        XCTAssertFalse(LocalFolderStatus.available.needsAttention)
        XCTAssertFalse(LocalFolderStatus.unknown.needsAttention)
    }

    func testSyncServiceSkipsPushAndPullWhenFolderIsMissing() async {
        let service = SyncService(processClient: UnreachableProcessClient(), localFolderChecker: AlwaysMissing())

        for outcome in [await service.push(makePair()), await service.pull(makePair()), await service.check(makePair())] {
            XCTAssertEqual(outcome.severity, .warning)
            XCTAssertTrue(outcome.summary.contains(storedPath))
        }
    }

    // Real filesystem: a folder renamed after the bookmark was taken.
    func testBookmarkFollowsRenamedFolder() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }
        let original = root.appendingPathComponent("before", isDirectory: true)
        let renamed = root.appendingPathComponent("after", isDirectory: true)
        try fileManager.createDirectory(at: original, withIntermediateDirectories: true)
        let bookmark = try original.bookmarkData(options: .minimalBookmark)
        try fileManager.moveItem(at: original, to: renamed)

        var pair = makePair(bookmark: bookmark)
        pair.localFolderDisplayPath = original.path
        let checker = LocalFolderAvailabilityChecker(resolver: BookmarkFolderResolver(), prober: POSIXPathProber())

        guard case let .moved(path, fresh) = checker.status(of: pair) else {
            return XCTFail("expected .moved")
        }
        XCTAssertEqual(URL(fileURLWithPath: path).resolvingSymlinksInPath(), renamed.resolvingSymlinksInPath())
        XCTAssertFalse(fresh.isEmpty)

        try fileManager.removeItem(at: renamed)
        XCTAssertEqual(checker.status(of: pair), .missing)
    }
}
