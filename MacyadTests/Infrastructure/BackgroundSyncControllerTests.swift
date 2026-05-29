import XCTest
@testable import MacyadCore

final class BackgroundSyncControllerTests: XCTestCase {
    func testRunCyclePersistsSuccessfulScheduledSyncAndAppendsActivity() async throws {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let now = Date(timeIntervalSince1970: 1_716_580_800)
        let pair = makePair(name: "Docs", lastSyncAt: now.addingTimeInterval(-4_000))
        let pairStore = InMemoryPairStore(pairs: [pair])
        let activityStore = InMemoryActivityStore()
        let notificationClient = RecordingNotificationClient()
        let scheduler = SchedulerService(
            policy: PushEligibilityPolicy(),
            syncService: SyncService(
                processClient: RecordingProcessClient(),
                localFolderInspector: StubLocalFolderInspector(containsUserVisibleContent: true),
                snapshotProvider: StubSnapshotProvider(snapshotsByPath: cleanSnapshots(for: [pair])),
                baselineRepository: InMemoryBaselineStore()
            )
        )
        let controller = BackgroundSyncController(
            scheduler: scheduler,
            pairStore: pairStore,
            activityStore: activityStore,
            notificationClient: notificationClient,
            now: { now },
            sleep: { _ in }
        )

        await controller.runCycle()

        let savedPairs = try await pairStore.load()
        let events = try await activityStore.load()
        let sentNotifications = await notificationClient.sentNotifications()

        XCTAssertEqual(savedPairs.count, 1)
        XCTAssertEqual(savedPairs[0].lastSyncAt, now)
        XCTAssertEqual(savedPairs[0].lastKnownSeverity, .healthy)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].severity, .healthy)
        XCTAssertTrue(events[0].message.contains("Scheduled Push to Yandex completed"))
        XCTAssertTrue(sentNotifications.isEmpty)
    }

    func testRunCyclePersistsSafeInitialPushIntoEmptyRemote() async throws {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let now = Date(timeIntervalSince1970: 1_716_580_800)
        let pair = makePair(name: "Seed", lastSyncAt: nil)
        let pairStore = InMemoryPairStore(pairs: [pair])
        let activityStore = InMemoryActivityStore()
        let notificationClient = RecordingNotificationClient()
        let scheduler = SchedulerService(
            policy: PushEligibilityPolicy(),
            syncService: SyncService(
                processClient: RecordingProcessClient(),
                localFolderInspector: StubLocalFolderInspector(containsUserVisibleContent: false),
                snapshotProvider: StubSnapshotProvider(
                    snapshotsByPath: [
                        pair.localFolderDisplayPath: snapshot(("seed.txt", "local")),
                        pair.remotePath: PairSnapshot(entries: []),
                    ]
                ),
                baselineRepository: InMemoryBaselineStore()
            )
        )
        let controller = BackgroundSyncController(
            scheduler: scheduler,
            pairStore: pairStore,
            activityStore: activityStore,
            notificationClient: notificationClient,
            now: { now },
            sleep: { _ in }
        )

        await controller.runCycle()

        let savedPairs = try await pairStore.load()
        let events = try await activityStore.load()
        let sentNotifications = await notificationClient.sentNotifications()

        XCTAssertEqual(savedPairs[0].lastKnownSeverity, .healthy)
        XCTAssertEqual(savedPairs[0].lastSyncAt, now)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].severity, .healthy)
        XCTAssertTrue(events[0].message.contains("Scheduled Push to Yandex completed"))
        XCTAssertTrue(sentNotifications.isEmpty)
    }

    func testRunCycleRecordsFailureAndSendsNotification() async throws {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let now = Date(timeIntervalSince1970: 1_716_580_800)
        let pair = makePair(name: "Photos", lastSyncAt: nil)
        let pairStore = InMemoryPairStore(pairs: [pair])
        let activityStore = InMemoryActivityStore()
        let notificationClient = RecordingNotificationClient()
        let scheduler = SchedulerService(
            policy: PushEligibilityPolicy(),
            syncService: SyncService(
                processClient: FailingProcessClient(),
                localFolderInspector: StubLocalFolderInspector(containsUserVisibleContent: true),
                snapshotProvider: StubSnapshotProvider(snapshotsByPath: cleanSnapshots(for: [pair])),
                baselineRepository: InMemoryBaselineStore()
            )
        )
        let controller = BackgroundSyncController(
            scheduler: scheduler,
            pairStore: pairStore,
            activityStore: activityStore,
            notificationClient: notificationClient,
            now: { now },
            sleep: { _ in }
        )

        await controller.runCycle()

        let savedPairs = try await pairStore.load()
        let events = try await activityStore.load()
        let sentNotifications = await notificationClient.sentNotifications()

        XCTAssertEqual(savedPairs[0].lastKnownSeverity, .alarm)
        XCTAssertNil(savedPairs[0].lastSyncAt)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].severity, .alarm)
        XCTAssertTrue(events[0].message.contains("Scheduled Push to Yandex failed"))
        XCTAssertTrue(events[0].details?.contains("permission denied") == true)
        XCTAssertTrue(events[0].details?.contains("NOTICE: remote object would be replaced") == true)
        XCTAssertEqual(sentNotifications.count, 1)
        XCTAssertEqual(sentNotifications[0].title, "MacYaD: scheduled Push to Yandex failed")
        XCTAssertTrue(sentNotifications[0].body.contains("Photos"))
    }

    func testRunCycleRecordsRemoteOnlyDriftBlockAndSendsNotification() async throws {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let now = Date(timeIntervalSince1970: 1_716_580_800)
        let pair = makePair(name: "RemoteSeed", lastSyncAt: nil)
        let pairStore = InMemoryPairStore(pairs: [pair])
        let activityStore = InMemoryActivityStore()
        let notificationClient = RecordingNotificationClient()
        let scheduler = SchedulerService(
            policy: PushEligibilityPolicy(),
            syncService: SyncService(
                processClient: RecordingProcessClient(),
                localFolderInspector: StubLocalFolderInspector(containsUserVisibleContent: false),
                snapshotProvider: StubSnapshotProvider(
                    snapshotsByPath: [
                        pair.localFolderDisplayPath: PairSnapshot(entries: []),
                        pair.remotePath: snapshot(("seed.txt", "remote")),
                    ]
                ),
                baselineRepository: InMemoryBaselineStore()
            )
        )
        let controller = BackgroundSyncController(
            scheduler: scheduler,
            pairStore: pairStore,
            activityStore: activityStore,
            notificationClient: notificationClient,
            now: { now },
            sleep: { _ in }
        )

        await controller.runCycle()

        let savedPairs = try await pairStore.load()
        let events = try await activityStore.load()
        let sentNotifications = await notificationClient.sentNotifications()

        XCTAssertEqual(savedPairs[0].lastKnownSeverity, .warning)
        XCTAssertNil(savedPairs[0].lastSyncAt)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].severity, .warning)
        XCTAssertEqual(events[0].message, "Scheduled Push to Yandex blocked")
        XCTAssertTrue(events[0].details?.contains("Problem: remote-only changed") == true)
        XCTAssertEqual(sentNotifications.count, 1)
        XCTAssertEqual(sentNotifications[0].title, "MacYaD: Push to Yandex blocked")
        XCTAssertTrue(sentNotifications[0].body.contains("RemoteSeed"))
    }

    func testStartDoesNotRunScheduledSyncBeforeFirstInterval() async throws {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let now = Date(timeIntervalSince1970: 1_716_580_800)
        let pair = makePair(name: "Docs", lastSyncAt: now.addingTimeInterval(-4_000))
        let pairStore = InMemoryPairStore(pairs: [pair])
        let activityStore = InMemoryActivityStore()
        let scheduler = SchedulerService(
            policy: PushEligibilityPolicy(),
            syncService: SyncService(
                processClient: RecordingProcessClient(),
                localFolderInspector: StubLocalFolderInspector(containsUserVisibleContent: true),
                snapshotProvider: StubSnapshotProvider(snapshotsByPath: cleanSnapshots(for: [pair])),
                baselineRepository: InMemoryBaselineStore()
            )
        )
        let controller = BackgroundSyncController(
            scheduler: scheduler,
            pairStore: pairStore,
            activityStore: activityStore,
            notificationClient: RecordingNotificationClient(),
            now: { now },
            sleep: { _ in throw CancellationError() }
        )

        await controller.start()
        try await Task.sleep(for: .milliseconds(50))
        await controller.stop()

        let savedPairs = try await pairStore.load()
        let events = try await activityStore.load()

        XCTAssertEqual(savedPairs[0].lastSyncAt, pair.lastSyncAt)
        XCTAssertTrue(events.isEmpty)
    }

    private func makePair(name: String, lastSyncAt: Date?) -> SyncPair {
        SyncPair(
            id: UUID(),
            name: name,
            localFolderBookmark: Data("bookmark".utf8),
            localFolderDisplayPath: "/Users/test/\(name)",
            remotePath: "yd:/\(name)",
            accountID: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            conflictPolicy: .block,
            scheduleMinutes: 30,
            deletePolicy: .mirrorToYandex,
            lastKnownSeverity: .healthy,
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

private actor InMemoryPairStore: PairStoreControlling {
    private var pairs: [SyncPair]

    init(pairs: [SyncPair]) {
        self.pairs = pairs
    }

    func load() async throws -> [SyncPair] {
        pairs
    }

    func save(_ pairs: [SyncPair]) async throws {
        self.pairs = pairs
    }
}

private actor InMemoryActivityStore: ActivityStoreControlling {
    private var events: [ActivityEvent] = []

    func load() async throws -> [ActivityEvent] {
        events
    }

    func append(_ event: ActivityEvent) async throws {
        events.append(event)
    }
}

private actor RecordingNotificationClient: UserNotificationSending {
    private var notifications: [(title: String, body: String, routeToken: ActivityRouteToken?)] = []

    func send(title: String, body: String, routeToken: ActivityRouteToken?) async throws {
        notifications.append((title: title, body: body, routeToken: routeToken))
    }

    func sentNotifications() -> [(title: String, body: String, routeToken: ActivityRouteToken?)] {
        notifications
    }
}

private actor RecordingProcessClient: RcloneProcessRunning {
    func run(_ arguments: [String]) async throws -> (stdout: String, stderr: String, exitCode: Int32) {
        ("", "", 0)
    }
}

private actor FailingProcessClient: RcloneProcessRunning {
    func run(_ arguments: [String]) async throws -> (stdout: String, stderr: String, exitCode: Int32) {
        ("NOTICE: remote object would be replaced", "permission denied", 12)
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
