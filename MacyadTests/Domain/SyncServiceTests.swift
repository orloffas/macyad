import XCTest
@testable import MacyadCore

final class SyncServiceTests: XCTestCase {
    func testPushDoesNotRunRcloneWhenLocalFolderIsEmpty() async throws {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let processClient = StubProcessClient(result: ("", "", 0))
        let service = SyncService(
            processClient: processClient,
            configPath: "/tmp/macyad-rclone.conf",
            localFolderInspector: StubLocalFolderInspector(containsUserVisibleContent: false)
        )

        do {
            try await service.push(makePair())
            XCTFail("Expected empty local folder guard to block push")
        } catch let error as SyncService.LocalFolderEmptyPushBlockedError {
            XCTAssertEqual(error.pairName, "Work Docs")
            XCTAssertEqual(
                error.localizedDescription,
                "Local folder is empty. Run Pull From Yandex first; Push to Yandex was blocked to avoid clearing Yandex."
            )
        }

        let recordedArguments = await processClient.recordedArguments()
        XCTAssertTrue(recordedArguments.isEmpty)
    }

    func testPushRunsRcloneWhenLocalFolderHasUserVisibleContent() async throws {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let processClient = StubProcessClient(result: ("", "", 0))
        let service = SyncService(
            processClient: processClient,
            configPath: "/tmp/macyad-rclone.conf",
            localFolderInspector: StubLocalFolderInspector(containsUserVisibleContent: true)
        )

        try await service.push(makePair())

        let recordedArguments = await processClient.recordedArguments()
        XCTAssertEqual(
            recordedArguments,
            [[
                "--config",
                "/tmp/macyad-rclone.conf",
                "sync",
                "/Users/test/Work Docs",
                "yd:/Work Docs",
                "--exclude",
                ".DS_Store",
                "--exclude",
                ".localized",
                "--exclude",
                "._*",
                "--exclude",
                ".Spotlight-V100/**",
                "--exclude",
                ".TemporaryItems/**",
                "--exclude",
                ".Trashes/**",
                "--exclude",
                ".fseventsd/**",
                "--exclude",
                "Thumbs.db",
                "--exclude",
                "desktop.ini",
                "--exclude",
                "$RECYCLE.BIN/**",
                "--exclude",
                "System Volume Information/**",
                "--exclude",
                "*.tmp",
                "--exclude",
                "*.temp",
                "--exclude",
                "*.swp",
                "--exclude",
                "*.swo",
                "--exclude",
                "*.part",
                "--exclude",
                "*.crdownload",
            ]]
        )
    }

    func testCheckReturnsWarningWhenRemoteChangesDetected() async throws {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let processClient = StubProcessClient(result: ("Transferred: 1 / 1, 100%", "", 0))
        let service = SyncService(processClient: processClient, configPath: "/tmp/macyad-rclone.conf")

        let outcome = try await service.check(makePair())

        XCTAssertEqual(outcome.severity, .warning)
        XCTAssertTrue(outcome.log.detailedDescription.contains("Transferred: 1 / 1, 100%"))
    }

    func testPullUsesCopyCommand() async throws {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let processClient = StubProcessClient(result: ("", "", 0))
        let service = SyncService(processClient: processClient, configPath: "/tmp/macyad-rclone.conf")

        try await service.pull(makePair())

        let recordedArguments = await processClient.recordedArguments()
        XCTAssertEqual(recordedArguments, [[
            "--config",
            "/tmp/macyad-rclone.conf",
            "copy",
            "yd:/Work Docs",
            "/Users/test/Work Docs",
            "--exclude",
            ".DS_Store",
            "--exclude",
            ".localized",
            "--exclude",
            "._*",
            "--exclude",
            ".Spotlight-V100/**",
            "--exclude",
            ".TemporaryItems/**",
            "--exclude",
            ".Trashes/**",
            "--exclude",
            ".fseventsd/**",
            "--exclude",
            "Thumbs.db",
            "--exclude",
            "desktop.ini",
            "--exclude",
            "$RECYCLE.BIN/**",
            "--exclude",
            "System Volume Information/**",
            "--exclude",
            "*.tmp",
            "--exclude",
            "*.temp",
            "--exclude",
            "*.swp",
            "--exclude",
            "*.swo",
            "--exclude",
            "*.part",
            "--exclude",
            "*.crdownload",
        ]])
    }

    func testCommandFailureDescriptionUsesSelectedLanguage() {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let error = SyncService.CommandFailedError(
            command: ["sync", "/tmp/source", "yd:/target"],
            exitCode: 12,
            stdout: "NOTICE: remote object would be replaced",
            stderr: "permission denied"
        )

        XCTAssertEqual(
            error.localizedDescription,
            "rclone sync /tmp/source yd:/target exited with code 12: permission denied"
        )
        XCTAssertTrue(error.detailedDescription.contains("NOTICE: remote object would be replaced"))
        XCTAssertTrue(error.detailedDescription.contains("permission denied"))
    }

    private func makePair() -> SyncPair {
        SyncPair(
            id: UUID(),
            name: "Work Docs",
            localFolderBookmark: Data("bookmark".utf8),
            localFolderDisplayPath: "/Users/test/Work Docs",
            remotePath: "yd:/Work Docs",
            scheduleMinutes: 30,
            deletePolicy: .mirrorToYandex,
            lastKnownSeverity: .healthy
        )
    }
}

private actor StubProcessClient: RcloneProcessRunning {
    private let result: (stdout: String, stderr: String, exitCode: Int32)
    private var argumentsLog: [[String]] = []

    init(result: (stdout: String, stderr: String, exitCode: Int32)) {
        self.result = result
    }

    func run(_ arguments: [String]) async throws -> (stdout: String, stderr: String, exitCode: Int32) {
        argumentsLog.append(arguments)
        return result
    }

    func recordedArguments() -> [[String]] {
        argumentsLog
    }
}

private struct StubLocalFolderInspector: LocalFolderInspecting {
    let containsUserVisibleContent: Bool

    func containsUserVisibleContent(atPath path: String) throws -> Bool {
        containsUserVisibleContent
    }

    func containsUserVisibleContent(atPath path: String, excludedPatterns: [String]) throws -> Bool {
        containsUserVisibleContent
    }
}
