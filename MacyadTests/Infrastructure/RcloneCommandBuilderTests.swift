import XCTest
@testable import MacyadCore

final class RcloneCommandBuilderTests: XCTestCase {
    func testRemoteCreateCommandUsesExplicitConfigPathBeforeRcloneSubcommand() {
        let command = RcloneCommandBuilder.remoteCreateCommand(
            configPath: "/Users/test/Library/Application Support/MacYaD/rclone/rclone.conf",
            remoteName: "yd"
        )

        XCTAssertEqual(
            command,
            "rclone --config '/Users/test/Library/Application Support/MacYaD/rclone/rclone.conf' config create yd yandex"
        )
    }

    func testSyncArgumentsUseExplicitConfigPath() {
        let arguments = RcloneCommandBuilder.syncArguments(
            for: makePair(),
            configPath: "/Users/test/Library/Application Support/MacYaD/rclone/rclone.conf"
        )

        XCTAssertEqual(
            arguments,
            [
                "--config",
                "/Users/test/Library/Application Support/MacYaD/rclone/rclone.conf",
                "sync",
                "/Users/test/Work Docs",
                "yd:/Work Docs",
            ]
        )
    }

    private func makePair() -> SyncPair {
        SyncPair(
            id: UUID(),
            name: "Work Docs",
            localFolderBookmark: Data("bookmark".utf8),
            localFolderDisplayPath: "/Users/test/Work Docs",
            remotePath: "yd:/Work Docs",
            scheduleMinutes: 15,
            deletePolicy: .mirrorToYandex,
            lastKnownSeverity: .healthy
        )
    }
}
