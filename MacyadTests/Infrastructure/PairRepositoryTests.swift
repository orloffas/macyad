import XCTest
@testable import MacyadCore

final class PairRepositoryTests: XCTestCase {
    func testSaveAndReloadPairsRoundTrips() async throws {
        let fileManager = FileManager.default
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let paths = AppPaths.makeForTesting(rootURL: root)
        let repository = PairRepository(store: JSONFileStore(url: paths.pairsFile))

        defer {
            try? fileManager.removeItem(at: root)
        }

        let pair = SyncPair(
            id: UUID(),
            name: "Work Docs",
            localFolderBookmark: Data(),
            localFolderDisplayPath: "/Users/test/Work Docs",
            remotePath: "yd:/Work Docs",
            scheduleMinutes: 30,
            deletePolicy: .mirrorToYandex,
            lastKnownSeverity: .healthy
        )

        try await repository.save([pair])
        let reloaded = try await repository.load()

        XCTAssertEqual(reloaded, [pair])
    }

    func testEnsureLayoutCreatesAppSupportAndWorkspaceDirectories() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let paths = AppPaths.makeForTesting(rootURL: root)

        defer {
            try? fileManager.removeItem(at: root)
        }

        try WorkspaceLayoutManager(paths: paths).ensureLayout()

        XCTAssertTrue(fileManager.directoryExists(at: paths.appSupportRoot))
        XCTAssertTrue(fileManager.directoryExists(at: paths.workspaceRoot))
    }
}

private extension FileManager {
    func directoryExists(at url: URL) -> Bool {
        var isDirectory = ObjCBool(false)
        let exists = fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
}
