import XCTest
@testable import MacyadCore

final class PairConflictStateRepositoryTests: XCTestCase {
    func testSaveAndReloadStateRoundTrips() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let paths = AppPaths.makeForTesting(rootURL: root)
        let repository = PairConflictStateRepository(paths: paths)

        defer {
            try? fileManager.removeItem(at: root)
        }

        let pairID = UUID()
        let state = PairConflictBaselineState(
            pairID: pairID,
            localSnapshot: PairSnapshot(entries: [
                PairSnapshotEntry(path: "Docs/a.txt", size: 5, modTime: Date(timeIntervalSince1970: 1_000), md5: "aaa")
            ]),
            remoteSnapshot: PairSnapshot(entries: [
                PairSnapshotEntry(path: "Docs/a.txt", size: 5, modTime: Date(timeIntervalSince1970: 1_000), md5: "aaa")
            ]),
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )

        try await repository.save(state)
        let reloaded = try await repository.load(pairID: pairID)

        XCTAssertEqual(reloaded, state)
    }
}
