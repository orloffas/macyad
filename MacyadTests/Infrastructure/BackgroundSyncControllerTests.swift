import XCTest
@testable import MacyadCore

final class BackgroundSyncControllerTests: XCTestCase {
    func testRunCyclePersistsSuccessfulScheduledSyncAndAppendsActivity() async throws {
        let now = Date(timeIntervalSince1970: 1_716_580_800)
        let pair = makePair(name: "Docs", lastSyncAt: now.addingTimeInterval(-4_000))
        let pairStore = InMemoryPairStore(pairs: [pair])
        let activityStore = InMemoryActivityStore()
        let notificationClient = RecordingNotificationClient()
        let scheduler = SchedulerService(
            policy: PushEligibilityPolicy(),
            syncService: SyncService(processClient: RecordingProcessClient())
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
        XCTAssertTrue(events[0].message.contains("Scheduled sync completed"))
        XCTAssertTrue(sentNotifications.isEmpty)
    }

    func testRunCycleRecordsFailureAndSendsNotification() async throws {
        let now = Date(timeIntervalSince1970: 1_716_580_800)
        let pair = makePair(name: "Photos", lastSyncAt: nil)
        let pairStore = InMemoryPairStore(pairs: [pair])
        let activityStore = InMemoryActivityStore()
        let notificationClient = RecordingNotificationClient()
        let scheduler = SchedulerService(
            policy: PushEligibilityPolicy(),
            syncService: SyncService(processClient: FailingProcessClient())
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
        XCTAssertTrue(events[0].message.contains("Scheduled sync failed"))
        XCTAssertEqual(sentNotifications.count, 1)
        XCTAssertEqual(sentNotifications[0].title, "MacYaD: scheduled sync failed")
        XCTAssertTrue(sentNotifications[0].body.contains("Photos"))
    }

    private func makePair(name: String, lastSyncAt: Date?) -> SyncPair {
        SyncPair(
            id: UUID(),
            name: name,
            localFolderBookmark: Data("bookmark".utf8),
            localFolderDisplayPath: "/Users/test/\(name)",
            remotePath: "yd:/\(name)",
            scheduleMinutes: 30,
            deletePolicy: .mirrorToYandex,
            lastKnownSeverity: .healthy,
            lastSyncAt: lastSyncAt
        )
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
    private var notifications: [(title: String, body: String)] = []

    func send(title: String, body: String) async throws {
        notifications.append((title: title, body: body))
    }

    func sentNotifications() -> [(title: String, body: String)] {
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
        ("", "permission denied", 12)
    }
}
