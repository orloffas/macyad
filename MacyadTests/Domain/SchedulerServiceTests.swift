import XCTest
@testable import MacyadCore

final class SchedulerServiceTests: XCTestCase {
    func testRunScheduledPushesRespectsScheduleInterval() async throws {
        let now = Date(timeIntervalSince1970: 1_716_580_800)
        let processClient = RecordingProcessClient()
        let service = SyncService(processClient: processClient)
        let scheduler = SchedulerService(policy: PushEligibilityPolicy(), syncService: service)
        let duePair = makePair(name: "Due", severity: .healthy, lastSyncAt: now.addingTimeInterval(-2_000))
        let notDuePair = makePair(name: "NotDue", severity: .healthy, lastSyncAt: now.addingTimeInterval(-300))

        let results = await scheduler.runScheduledPushes(for: [duePair, notDuePair], now: now)
        let recordedArguments = await processClient.recordedArguments()

        XCTAssertEqual(results.map(\.disposition), [.pushed, .skippedNotDue])
        XCTAssertEqual(results.map(\.pair.id), [duePair.id, notDuePair.id])
        XCTAssertEqual(results.first?.pair.lastSyncAt, now)
        XCTAssertEqual(results.last?.pair.lastSyncAt, notDuePair.lastSyncAt)
        XCTAssertEqual(recordedArguments, [["sync", duePair.localFolderDisplayPath, duePair.remotePath]])
    }

    func testRunScheduledPushesSkipsAlarmPairs() async throws {
        let now = Date(timeIntervalSince1970: 1_716_580_800)
        let processClient = RecordingProcessClient()
        let service = SyncService(processClient: processClient)
        let scheduler = SchedulerService(policy: PushEligibilityPolicy(), syncService: service)
        let healthyPair = makePair(name: "Healthy", severity: .healthy, lastSyncAt: nil)
        let alarmPair = makePair(name: "Alarm", severity: .alarm, lastSyncAt: nil)

        let results = await scheduler.runScheduledPushes(for: [healthyPair, alarmPair], now: now)
        let recordedArguments = await processClient.recordedArguments()

        XCTAssertEqual(results.map(\.disposition), [.pushed, .skippedByPolicy])
        XCTAssertEqual(results.first?.pair.lastSyncAt, now)
        XCTAssertNil(results.last?.pair.lastSyncAt)
        XCTAssertEqual(recordedArguments.count, 1)
        XCTAssertEqual(recordedArguments.first, ["sync", healthyPair.localFolderDisplayPath, healthyPair.remotePath])
    }

    func testRunScheduledPushesMarksFailuresAsAlarm() async {
        let now = Date(timeIntervalSince1970: 1_716_580_800)
        let processClient = FailingProcessClient()
        let service = SyncService(processClient: processClient)
        let scheduler = SchedulerService(policy: PushEligibilityPolicy(), syncService: service)
        let pair = makePair(name: "Broken", severity: .healthy, lastSyncAt: nil)

        let results = await scheduler.runScheduledPushes(for: [pair], now: now)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].pair.lastKnownSeverity, .alarm)
        XCTAssertNil(results[0].pair.lastSyncAt)

        guard case let .failed(message) = results[0].disposition else {
            return XCTFail("Expected failed disposition")
        }

        XCTAssertTrue(message.contains("завершился с кодом 9"))
    }

    func testPolicyBlocksAlarmPairsFromScheduledPush() {
        let policy = PushEligibilityPolicy()

        XCTAssertFalse(policy.canRunScheduledPush(for: makePair(name: "Alarm", severity: .alarm, lastSyncAt: nil)))
        XCTAssertTrue(policy.canRunScheduledPush(for: makePair(name: "Warning", severity: .warning, lastSyncAt: nil)))
    }

    private func makePair(name: String, severity: Severity, lastSyncAt: Date?) -> SyncPair {
        SyncPair(
            id: UUID(),
            name: name,
            localFolderBookmark: Data("bookmark".utf8),
            localFolderDisplayPath: "/Users/test/\(name)",
            remotePath: "yd:/\(name)",
            scheduleMinutes: 30,
            deletePolicy: .mirrorToYandex,
            lastKnownSeverity: severity,
            lastSyncAt: lastSyncAt
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

private actor FailingProcessClient: RcloneProcessRunning {
    func run(_ arguments: [String]) async throws -> (stdout: String, stderr: String, exitCode: Int32) {
        ("", "network exploded", 9)
    }
}
