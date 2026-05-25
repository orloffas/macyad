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
                "--exclude",
                ".DS_Store",
                "--exclude",
                "Thumbs.db",
            ]
        )
    }

    func testCheckArgumentsApplySyncAndAdditionalCheckExcludes() {
        let arguments = RcloneCommandBuilder.checkArguments(
            for: makePair(
                syncExcludes: [".DS_Store", "Thumbs.db"],
                checkAdditionalExcludes: ["Desktop.ini"]
            ),
            configPath: "/Users/test/Library/Application Support/MacYaD/rclone/rclone.conf"
        )

        XCTAssertEqual(
            arguments,
            [
                "--config",
                "/Users/test/Library/Application Support/MacYaD/rclone/rclone.conf",
                "check",
                "/Users/test/Work Docs",
                "yd:/Work Docs",
                "--one-way",
                "--exclude",
                ".DS_Store",
                "--exclude",
                "Thumbs.db",
                "--exclude",
                "Desktop.ini",
            ]
        )
    }

    func testPullArgumentsApplySyncExcludes() {
        let arguments = RcloneCommandBuilder.pullArguments(
            for: makePair(syncExcludes: [".DS_Store", "Thumbs.db"]),
            configPath: "/Users/test/Library/Application Support/MacYaD/rclone/rclone.conf"
        )

        XCTAssertEqual(
            arguments,
            [
                "--config",
                "/Users/test/Library/Application Support/MacYaD/rclone/rclone.conf",
                "copy",
                "yd:/Work Docs",
                "/Users/test/Work Docs",
                "--exclude",
                ".DS_Store",
                "--exclude",
                "Thumbs.db",
            ]
        )
    }

    private func makePair(
        syncExcludes: [String] = [".DS_Store", "Thumbs.db"],
        checkAdditionalExcludes: [String] = []
    ) -> SyncPair {
        SyncPair(
            id: UUID(),
            name: "Work Docs",
            localFolderBookmark: Data("bookmark".utf8),
            localFolderDisplayPath: "/Users/test/Work Docs",
            remotePath: "yd:/Work Docs",
            scheduleMinutes: 15,
            deletePolicy: .mirrorToYandex,
            lastKnownSeverity: .healthy,
            syncExcludes: syncExcludes,
            checkAdditionalExcludes: checkAdditionalExcludes
        )
    }
}
