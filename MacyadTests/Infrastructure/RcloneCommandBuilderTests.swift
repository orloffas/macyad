import XCTest
@testable import MacyadCore

final class RcloneCommandBuilderTests: XCTestCase {
    func testRemoteCreateCommandRunsBundledConnectScriptWithExplicitConfigPath() {
        let command = RcloneCommandBuilder.remoteCreateCommand(
            configPath: "/Users/test/Library/Application Support/MacYaD/rclone/rclone.conf",
            remoteName: "yd",
            scriptPath: "/Applications/MacYaD.app/Contents/Resources/connect_yandex.py"
        )

        XCTAssertEqual(
            command,
            "python3 '/Applications/MacYaD.app/Contents/Resources/connect_yandex.py' --config '/Users/test/Library/Application Support/MacYaD/rclone/rclone.conf' --remote yd"
        )
    }

    func testRemoteReconnectCommandReusesConnectScriptInsteadOfRcloneReconnect() {
        let reconnect = RcloneCommandBuilder.remoteReconnectCommand(configPath: "/Users/test/rclone.conf", remoteName: "yd", scriptPath: "/s.py")

        XCTAssertEqual(reconnect, RcloneCommandBuilder.remoteCreateCommand(configPath: "/Users/test/rclone.conf", remoteName: "yd", scriptPath: "/s.py"))
        XCTAssertFalse(reconnect.contains("config reconnect"))
    }

    func testSyncArgumentsUseExplicitConfigPath() {
        let arguments = RcloneCommandBuilder.syncArguments(
            for: makePair(),
            configPath: "/Users/test/Library/Application Support/MacYaD/rclone/rclone.conf",
            excludeFilePath: "/Users/test/Library/Application Support/MacYaD/rclone/filters/sync.txt"
        )

        XCTAssertEqual(
            arguments,
            [
                "--config",
                "/Users/test/Library/Application Support/MacYaD/rclone/rclone.conf",
                "sync",
                "/Users/test/Work Docs",
                "yd:/Work Docs",
                "--exclude-from",
                "/Users/test/Library/Application Support/MacYaD/rclone/filters/sync.txt",
            ]
        )
    }

    func testCheckArgumentsApplySyncAndAdditionalCheckExcludes() {
        let arguments = RcloneCommandBuilder.checkArguments(
            for: makePair(
                syncExcludes: [".DS_Store", "Thumbs.db"],
                checkAdditionalExcludes: ["Desktop.ini"]
            ),
            configPath: "/Users/test/Library/Application Support/MacYaD/rclone/rclone.conf",
            excludeFilePath: "/Users/test/Library/Application Support/MacYaD/rclone/filters/check.txt"
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
                "--exclude-from",
                "/Users/test/Library/Application Support/MacYaD/rclone/filters/check.txt",
            ]
        )
    }

    func testPullArgumentsApplySyncExcludes() {
        let arguments = RcloneCommandBuilder.pullArguments(
            for: makePair(syncExcludes: [".DS_Store", "Thumbs.db"]),
            configPath: "/Users/test/Library/Application Support/MacYaD/rclone/rclone.conf",
            excludeFilePath: "/Users/test/Library/Application Support/MacYaD/rclone/filters/sync.txt"
        )

        XCTAssertEqual(
            arguments,
            [
                "--config",
                "/Users/test/Library/Application Support/MacYaD/rclone/rclone.conf",
                "copy",
                "yd:/Work Docs",
                "/Users/test/Work Docs",
                "--exclude-from",
                "/Users/test/Library/Application Support/MacYaD/rclone/filters/sync.txt",
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
