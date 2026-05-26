import XCTest
@testable import MacyadCore

final class SchedulerServiceTests: XCTestCase {
    func testRunScheduledPushesRespectsScheduleInterval() async throws {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let now = Date(timeIntervalSince1970: 1_716_580_800)
        let processClient = RecordingProcessClient()
        let excludeFileStore = StubExcludeFileStore()
        let service = SyncService(
            processClient: processClient,
            localFolderInspector: StubLocalFolderInspector(containsUserVisibleContent: true),
            excludeFileStore: excludeFileStore
        )
        let scheduler = SchedulerService(policy: PushEligibilityPolicy(), syncService: service)
        let duePair = makePair(name: "Due", severity: .healthy, lastSyncAt: now.addingTimeInterval(-2_000))
        let notDuePair = makePair(name: "NotDue", severity: .healthy, lastSyncAt: now.addingTimeInterval(-300))

        let results = await scheduler.runScheduledPushes(for: [duePair, notDuePair], now: now)
        let recordedArguments = await processClient.recordedArguments()

        XCTAssertEqual(results.map(\.disposition), [.pushed, .skippedNotDue])
        XCTAssertEqual(results.map(\.pair.id), [duePair.id, notDuePair.id])
        XCTAssertEqual(results.first?.pair.lastSyncAt, now)
        XCTAssertEqual(results.last?.pair.lastSyncAt, notDuePair.lastSyncAt)
        XCTAssertEqual(recordedArguments, [[
            "sync",
            duePair.localFolderDisplayPath,
            duePair.remotePath,
            "--exclude-from",
            "/tmp/sync-excludes.txt",
        ]])
    }

    func testRunScheduledPushesSkipsAlarmPairs() async throws {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let now = Date(timeIntervalSince1970: 1_716_580_800)
        let processClient = RecordingProcessClient()
        let excludeFileStore = StubExcludeFileStore()
        let service = SyncService(
            processClient: processClient,
            localFolderInspector: StubLocalFolderInspector(containsUserVisibleContent: true),
            excludeFileStore: excludeFileStore
        )
        let scheduler = SchedulerService(policy: PushEligibilityPolicy(), syncService: service)
        let healthyPair = makePair(name: "Healthy", severity: .healthy, lastSyncAt: nil)
        let alarmPair = makePair(name: "Alarm", severity: .alarm, lastSyncAt: nil)

        let results = await scheduler.runScheduledPushes(for: [healthyPair, alarmPair], now: now)
        let recordedArguments = await processClient.recordedArguments()

        XCTAssertEqual(results.map(\.disposition), [.pushed, .skippedByPolicy])
        XCTAssertEqual(results.first?.pair.lastSyncAt, now)
        XCTAssertNil(results.last?.pair.lastSyncAt)
        XCTAssertEqual(recordedArguments.count, 1)
        XCTAssertEqual(recordedArguments.first, [
            "sync",
            healthyPair.localFolderDisplayPath,
            healthyPair.remotePath,
            "--exclude-from",
            "/tmp/sync-excludes.txt",
        ])
    }

    func testRunScheduledPushesMarksFailuresAsAlarm() async {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let now = Date(timeIntervalSince1970: 1_716_580_800)
        let processClient = FailingProcessClient()
        let service = SyncService(
            processClient: processClient,
            localFolderInspector: StubLocalFolderInspector(containsUserVisibleContent: true)
        )
        let scheduler = SchedulerService(policy: PushEligibilityPolicy(), syncService: service)
        let pair = makePair(name: "Broken", severity: .healthy, lastSyncAt: nil)

        let results = await scheduler.runScheduledPushes(for: [pair], now: now)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].pair.lastKnownSeverity, .alarm)
        XCTAssertNil(results[0].pair.lastSyncAt)

        guard case let .failed(summary, details) = results[0].disposition else {
            return XCTFail("Expected failed disposition")
        }

        XCTAssertTrue(summary.contains("exited with code 9"))
        XCTAssertTrue(summary.contains("network exploded"))
        XCTAssertTrue(details.contains("network exploded"))
    }

    func testRunScheduledPushesBlocksEmptyLocalFolderAsWarning() async {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let now = Date(timeIntervalSince1970: 1_716_580_800)
        let processClient = RecordingProcessClient()
        let service = SyncService(
            processClient: processClient,
            localFolderInspector: StubLocalFolderInspector(containsUserVisibleContent: false)
        )
        let scheduler = SchedulerService(policy: PushEligibilityPolicy(), syncService: service)
        let pair = makePair(name: "Empty", severity: .healthy, lastSyncAt: nil)

        let results = await scheduler.runScheduledPushes(for: [pair], now: now)
        let recordedArguments = await processClient.recordedArguments()

        XCTAssertTrue(recordedArguments.isEmpty)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].pair.lastKnownSeverity, .warning)
        XCTAssertNil(results[0].pair.lastSyncAt)

        guard case let .blockedEmptyLocalFolder(summary, details) = results[0].disposition else {
            return XCTFail("Expected empty local folder block")
        }

        XCTAssertTrue(summary.contains("Local folder is empty"))
        XCTAssertTrue(details.contains("Local folder is empty"))
    }

    func testRunScheduledPushesDoesNotRepeatBlockedAttemptBeforeScheduleInterval() async {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let now = Date(timeIntervalSince1970: 1_716_580_800)
        let processClient = RecordingProcessClient()
        let service = SyncService(
            processClient: processClient,
            localFolderInspector: StubLocalFolderInspector(containsUserVisibleContent: false)
        )
        let scheduler = SchedulerService(policy: PushEligibilityPolicy(), syncService: service)
        let pair = makePair(name: "Empty", severity: .healthy, lastSyncAt: nil)

        let firstResults = await scheduler.runScheduledPushes(for: [pair], now: now)
        let secondResults = await scheduler.runScheduledPushes(for: [firstResults[0].pair], now: now.addingTimeInterval(60))

        guard case .blockedEmptyLocalFolder = firstResults[0].disposition else {
            return XCTFail("Expected initial blocked disposition")
        }

        XCTAssertEqual(firstResults[0].pair.lastScheduledPushAttemptAt, now)
        XCTAssertEqual(secondResults.map(\.disposition), [.skippedNotDue])
        XCTAssertEqual(secondResults[0].pair.lastScheduledPushAttemptAt, now)
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

private struct StubExcludeFileStore: RcloneExcludeFilePreparing {
    func prepareExcludeFile(for pair: SyncPair, mode: RcloneExcludeFileMode) throws -> String? {
        switch mode {
        case .sync:
            return "/tmp/sync-excludes.txt"
        case .check:
            return "/tmp/check-excludes.txt"
        }
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

private struct StubLocalFolderInspector: LocalFolderInspecting {
    let containsUserVisibleContent: Bool

    func containsUserVisibleContent(atPath path: String) throws -> Bool {
        containsUserVisibleContent
    }

    func containsUserVisibleContent(atPath path: String, excludedPatterns: [String]) throws -> Bool {
        containsUserVisibleContent
    }
}
