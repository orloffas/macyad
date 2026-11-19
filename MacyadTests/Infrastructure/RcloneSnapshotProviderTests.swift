import XCTest
@testable import MacyadCore

final class RcloneSnapshotProviderTests: XCTestCase {
    func testSnapshotReadsTheLowerCaseMD5KeyRcloneActuallyPrints() async throws {
        // Verbatim shape of `rclone lsjson --hash --hash-type MD5` output.
        let stdout = """
        [{"Path":"Docs/scan.pdf","Name":"scan.pdf","Size":12,"MimeType":"application/pdf","ModTime":"2023-03-16T23:13:49Z","IsDir":false,"Hashes":{"md5":"b56542e9428f8b8ff2dc643b8da8845b"}}]
        """
        let provider = RcloneSnapshotProvider(processClient: ListingProcessClient(stdout: stdout))

        let snapshot = try await provider.snapshot(for: makePair(), path: "yd:/Work Docs", mode: .sync)

        XCTAssertEqual(snapshot.entries.first?.md5, "b56542e9428f8b8ff2dc643b8da8845b")
    }

    private func makePair() -> SyncPair {
        SyncPair(
            id: UUID(),
            name: "Work Docs",
            localFolderBookmark: Data("bookmark".utf8),
            localFolderDisplayPath: "/Users/test/Work Docs",
            remotePath: "yd:/Work Docs",
            accountID: UUID(),
            conflictPolicy: .block,
            scheduleMinutes: 30,
            deletePolicy: .mirrorToYandex,
            lastKnownSeverity: .healthy
        )
    }
}

private struct ListingProcessClient: RcloneProcessRunning {
    let stdout: String

    func run(_ arguments: [String]) async throws -> (stdout: String, stderr: String, exitCode: Int32) {
        (stdout, "", 0)
    }

    func runStreaming(_ arguments: [String]) async throws -> RcloneStreamingHandle {
        let result = try await run(arguments)
        let (stream, continuation) = AsyncStream.makeStream(of: String.self)
        continuation.finish()
        return RcloneStreamingHandle(lines: stream, completion: Task { result })
    }
}
