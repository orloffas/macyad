import XCTest
@testable import MacyadCore

final class SchedulerServiceTests: XCTestCase {
    func testRunScheduledPushesRespectsScheduleInterval() async throws {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let now = Date(timeIntervalSince1970: 1_716_580_800)
        let duePair = makePair(name: "Due", severity: .healthy, lastSyncAt: now.addingTimeInterval(-2_000))
        let notDuePair = makePair(name: "NotDue", severity: .healthy, lastSyncAt: now.addingTimeInterval(-300))
        let processClient = RecordingProcessClient()
        let excludeFileStore = StubExcludeFileStore()
        let service = SyncService(
            processClient: processClient,
            localFolderInspector: StubLocalFolderInspector(containsUserVisibleContent: true),
            excludeFileStore: excludeFileStore,
            snapshotProvider: StubSnapshotProvider(snapshotsByPath: cleanSnapshots(for: [duePair, notDuePair])),
            baselineRepository: InMemoryBaselineStore()
        )
        let scheduler = SchedulerService(policy: PushEligibilityPolicy(), syncService: service)

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
        let healthyPair = makePair(name: "Healthy", severity: .healthy, lastSyncAt: nil)
        let alarmPair = makePair(name: "Alarm", severity: .alarm, lastSyncAt: nil)
        let processClient = RecordingProcessClient()
        let excludeFileStore = StubExcludeFileStore()
        let service = SyncService(
            processClient: processClient,
            localFolderInspector: StubLocalFolderInspector(containsUserVisibleContent: true),
            excludeFileStore: excludeFileStore,
            snapshotProvider: StubSnapshotProvider(snapshotsByPath: cleanSnapshots(for: [healthyPair, alarmPair])),
            baselineRepository: InMemoryBaselineStore()
        )
        let scheduler = SchedulerService(policy: PushEligibilityPolicy(), syncService: service)

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
        let pair = makePair(name: "Broken", severity: .healthy, lastSyncAt: nil)
        let processClient = FailingProcessClient()
        let service = SyncService(
            processClient: processClient,
            localFolderInspector: StubLocalFolderInspector(containsUserVisibleContent: true),
            snapshotProvider: StubSnapshotProvider(snapshotsByPath: cleanSnapshots(for: [pair])),
            baselineRepository: InMemoryBaselineStore()
        )
        let scheduler = SchedulerService(policy: PushEligibilityPolicy(), syncService: service)

        let results = await scheduler.runScheduledPushes(for: [pair], now: now)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].pair.lastKnownSeverity, Severity.alarm)
        XCTAssertNil(results[0].pair.lastSyncAt)

        guard case let .failed(summary, details, _) = results[0].disposition else {
            return XCTFail("Expected failed disposition")
        }

        XCTAssertTrue(summary.contains("exited with code 9"))
        XCTAssertTrue(summary.contains("network exploded"))
        XCTAssertTrue(details.contains("network exploded"))
    }

    func testRunScheduledPushesAllowsInitialPushWhenRemoteIsEmpty() async {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let now = Date(timeIntervalSince1970: 1_716_580_800)
        let processClient = RecordingProcessClient()
        let pair = makePair(name: "Seed", severity: .healthy, lastSyncAt: nil)
        let service = SyncService(
            processClient: processClient,
            localFolderInspector: StubLocalFolderInspector(containsUserVisibleContent: false),
            snapshotProvider: StubSnapshotProvider(
                snapshotsByPath: [
                    pair.localFolderDisplayPath: snapshot(("seed.txt", "local")),
                    pair.remotePath: PairSnapshot(entries: []),
                ]
            ),
            baselineRepository: InMemoryBaselineStore()
        )
        let scheduler = SchedulerService(policy: PushEligibilityPolicy(), syncService: service)

        let results = await scheduler.runScheduledPushes(for: [pair], now: now)
        let recordedArguments = await processClient.recordedArguments()

        XCTAssertEqual(recordedArguments.count, 1)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].pair.lastKnownSeverity, .healthy)
        XCTAssertEqual(results[0].pair.lastSyncAt, now)

        guard case .pushed = results[0].disposition else {
            return XCTFail("Expected pushed disposition")
        }
    }

    func testRunScheduledPushesDoesNotRepeatBlockedAttemptBeforeScheduleInterval() async {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let now = Date(timeIntervalSince1970: 1_716_580_800)
        let processClient = RecordingProcessClient()
        let pair = makePair(name: "RemoteSeed", severity: .healthy, lastSyncAt: nil)
        let service = SyncService(
            processClient: processClient,
            localFolderInspector: StubLocalFolderInspector(containsUserVisibleContent: false),
            snapshotProvider: StubSnapshotProvider(
                snapshotsByPath: [
                    pair.localFolderDisplayPath: PairSnapshot(entries: []),
                    pair.remotePath: snapshot(("seed.txt", "remote")),
                ]
            ),
            baselineRepository: InMemoryBaselineStore()
        )
        let scheduler = SchedulerService(policy: PushEligibilityPolicy(), syncService: service)

        let firstResults = await scheduler.runScheduledPushes(for: [pair], now: now)
        let secondResults = await scheduler.runScheduledPushes(for: [firstResults[0].pair], now: now.addingTimeInterval(60))

        guard case .blocked = firstResults[0].disposition else {
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

    func testSnapshotAPIGlobalPausedSkipsAllPairs() async {
        let now = Date(timeIntervalSince1970: 1_716_580_800)
        let pair1 = makePair(name: "A", severity: .healthy, lastSyncAt: nil)
        let pair2 = makePair(name: "B", severity: .healthy, lastSyncAt: nil)
        let scheduler = SchedulerService(policy: PushEligibilityPolicy(), syncServiceProvider: { fatalError("should not be called") })
        let pausedPrefs = AppPreferences(selectedLanguage: "en", launchAtLoginEnabled: true, defaultScheduleMinutes: 15, isGlobalSchedulerPaused: true)
        let snapshot = SchedulerSnapshot(pairs: [pair1, pair2], preferences: pausedPrefs)

        let results = await scheduler.runScheduledPushes(snapshot: snapshot, now: now)

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].disposition, .skippedByPolicy)
        XCTAssertEqual(results[1].disposition, .skippedByPolicy)
    }

    func testSnapshotAPIGlobalRunningPerPairOffSkipsThatPair() async throws {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let now = Date(timeIntervalSince1970: 1_716_580_800)
        var pairOff = makePair(name: "Off", severity: .healthy, lastSyncAt: nil)
        pairOff.isAutoPushEnabled = false
        let pairOn = makePair(name: "On", severity: .healthy, lastSyncAt: nil)
        let processClient = RecordingProcessClient()
        let service = SyncService(
            processClient: processClient,
            localFolderInspector: StubLocalFolderInspector(containsUserVisibleContent: true),
            snapshotProvider: StubSnapshotProvider(snapshotsByPath: cleanSnapshots(for: [pairOff, pairOn])),
            baselineRepository: InMemoryBaselineStore()
        )
        let scheduler = SchedulerService(policy: PushEligibilityPolicy(), syncService: service)
        let prefs = AppPreferences.defaults
        let snapshot = SchedulerSnapshot(pairs: [pairOff, pairOn], preferences: prefs)

        let results = await scheduler.runScheduledPushes(snapshot: snapshot, now: now)

        XCTAssertEqual(results[0].disposition, .skippedByPolicy)
        XCTAssertEqual(results[1].disposition, .pushed)
    }

    func testSnapshotAPIBothOnAndDuePushRuns() async throws {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let now = Date(timeIntervalSince1970: 1_716_580_800)
        let pair = makePair(name: "Both", severity: .healthy, lastSyncAt: nil)
        let processClient = RecordingProcessClient()
        let service = SyncService(
            processClient: processClient,
            localFolderInspector: StubLocalFolderInspector(containsUserVisibleContent: true),
            snapshotProvider: StubSnapshotProvider(snapshotsByPath: cleanSnapshots(for: [pair])),
            baselineRepository: InMemoryBaselineStore()
        )
        let scheduler = SchedulerService(policy: PushEligibilityPolicy(), syncService: service)
        let snapshot = SchedulerSnapshot(pairs: [pair], preferences: .defaults)

        let results = await scheduler.runScheduledPushes(snapshot: snapshot, now: now)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].disposition, .pushed)
    }

    private func makePair(name: String, severity: Severity, lastSyncAt: Date?) -> SyncPair {
        SyncPair(
            id: UUID(),
            name: name,
            localFolderBookmark: Data("bookmark".utf8),
            localFolderDisplayPath: "/Users/test/\(name)",
            remotePath: "yd:/\(name)",
            accountID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            conflictPolicy: .block,
            scheduleMinutes: 30,
            deletePolicy: .mirrorToYandex,
            lastKnownSeverity: severity,
            lastSyncAt: lastSyncAt
        )
    }

    private func cleanSnapshots(for pairs: [SyncPair]) -> [String: PairSnapshot] {
        var snapshots: [String: PairSnapshot] = [:]
        let empty = PairSnapshot(entries: [])
        for pair in pairs {
            snapshots[pair.localFolderDisplayPath] = empty
            snapshots[pair.remotePath] = empty
        }
        return snapshots
    }

    private func snapshot(_ files: (String, String)...) -> PairSnapshot {
        PairSnapshot(entries: files.map { path, hash in
            PairSnapshotEntry(path: path, size: Int64(hash.count), modTime: Date(timeIntervalSince1970: 1_000), md5: hash)
        })
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

    func runStreaming(_ arguments: [String]) async throws -> RcloneStreamingHandle {
        let result = try await run(arguments)
        let (stream, continuation) = AsyncStream.makeStream(of: String.self)
        continuation.finish()
        return RcloneStreamingHandle(
            lines: stream,
            completion: Task { result }
        )
    }

    func recordedArguments() -> [[String]] {
        argumentsLog
    }
}

private actor FailingProcessClient: RcloneProcessRunning {
    func run(_ arguments: [String]) async throws -> (stdout: String, stderr: String, exitCode: Int32) {
        ("", "network exploded", 9)
    }

    func runStreaming(_ arguments: [String]) async throws -> RcloneStreamingHandle {
        let result = try await run(arguments)
        let (stream, continuation) = AsyncStream.makeStream(of: String.self)
        continuation.finish()
        return RcloneStreamingHandle(
            lines: stream,
            completion: Task { result }
        )
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

private struct StubSnapshotProvider: PairSnapshotProviding {
    let snapshotsByPath: [String: PairSnapshot]

    func snapshot(for pair: SyncPair, path: String, mode: RcloneExcludeFileMode) async throws -> PairSnapshot {
        snapshotsByPath[path] ?? PairSnapshot(entries: [])
    }
}

private actor InMemoryBaselineStore: PairConflictStateStoring {
    private var states: [UUID: PairConflictBaselineState] = [:]

    func load(pairID: UUID) async throws -> PairConflictBaselineState? {
        states[pairID]
    }

    func save(_ state: PairConflictBaselineState) async throws {
        states[state.pairID] = state
    }

    func remove(pairID: UUID) async throws {
        states[pairID] = nil
    }
}
