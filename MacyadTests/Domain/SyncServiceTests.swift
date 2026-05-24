import XCTest
@testable import MacyadCore

final class SyncServiceTests: XCTestCase {
    func testCheckReturnsWarningWhenRemoteChangesDetected() async throws {
        let processClient = StubProcessClient(result: ("Transferred: 1 / 1, 100%", "", 0))
        let service = SyncService(processClient: processClient)

        let severity = try await service.check(makePair())

        XCTAssertEqual(severity, .warning)
    }

    func testPullUsesCopyCommand() async throws {
        let processClient = StubProcessClient(result: ("", "", 0))
        let service = SyncService(processClient: processClient)

        try await service.pull(makePair())

        let recordedArguments = await processClient.recordedArguments()
        XCTAssertEqual(recordedArguments, [["copy", "yd:/Work Docs", "/Users/test/Work Docs"]])
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
