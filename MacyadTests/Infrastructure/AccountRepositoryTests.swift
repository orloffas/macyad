import XCTest
@testable import MacyadCore

final class AccountRepositoryTests: XCTestCase {
    func testSaveAndReloadAccountsRoundTrips() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let paths = AppPaths.makeForTesting(rootURL: root)
        let repository = AccountRepository(store: JSONFileStore(url: paths.accountsFile))

        defer {
            try? fileManager.removeItem(at: root)
        }

        let account = YandexAccount(
            id: UUID(),
            displayName: "Personal",
            remoteName: "yd-personal",
            configPath: paths.rcloneConfigFile.path,
            isManaged: true
        )

        try await repository.save([account])
        let reloaded = try await repository.load()

        XCTAssertEqual(reloaded, [account])
    }
}
