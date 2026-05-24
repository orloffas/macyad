import XCTest
@testable import MacyadCore

final class SchedulerServiceTests: XCTestCase {
    func testRunScheduledPushesSkipsAlarmPairs() async throws {
        let processClient = RecordingProcessClient()
        let service = SyncService(processClient: processClient)
        let scheduler = SchedulerService(policy: PushEligibilityPolicy(), syncService: service)
        let healthyPair = makePair(name: "Healthy", severity: .healthy)
        let alarmPair = makePair(name: "Alarm", severity: .alarm)

        let executedPairIDs = await scheduler.runScheduledPushes(for: [healthyPair, alarmPair])
        let recordedArguments = await processClient.recordedArguments()

        XCTAssertEqual(executedPairIDs, [healthyPair.id])
        XCTAssertEqual(recordedArguments.count, 1)
        XCTAssertEqual(recordedArguments.first, ["sync", healthyPair.localFolderDisplayPath, healthyPair.remotePath])
    }

    func testPolicyBlocksAlarmPairsFromScheduledPush() {
        let policy = PushEligibilityPolicy()

        XCTAssertFalse(policy.canRunScheduledPush(for: makePair(name: "Alarm", severity: .alarm)))
        XCTAssertTrue(policy.canRunScheduledPush(for: makePair(name: "Warning", severity: .warning)))
    }

    private func makePair(name: String, severity: Severity) -> SyncPair {
        SyncPair(
            id: UUID(),
            name: name,
            localFolderBookmark: Data("bookmark".utf8),
            localFolderDisplayPath: "/Users/test/\(name)",
            remotePath: "yd:/\(name)",
            scheduleMinutes: 30,
            deletePolicy: .mirrorToYandex,
            lastKnownSeverity: severity
        )
    }
}

private actor RecordingProcessClient: RcloneProcessRunning {
    private var argumentsLog: [[String]] = []

    func run(_ arguments: [String]) async throws -> (stdout: String, stderr: String, exitCode: Int32) {
        argumentsLog.append(arguments)
        return ("", "", 0)
    }

    func recordedArguments() -> [[String]] {
        argumentsLog
    }
}
