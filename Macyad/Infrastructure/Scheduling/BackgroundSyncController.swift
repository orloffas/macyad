import Foundation

public protocol PairStoreControlling: Sendable {
    func load() async throws -> [SyncPair]
    func save(_ pairs: [SyncPair]) async throws
}

public protocol ActivityStoreControlling: Sendable {
    func load() async throws -> [ActivityEvent]
    func append(_ event: ActivityEvent) async throws
}

public protocol UserNotificationSending: Sendable {
    func send(title: String, body: String) async throws
}

extension PairRepository: PairStoreControlling {}
extension ActivityRepository: ActivityStoreControlling {}
extension UserNotificationClient: UserNotificationSending {}

public actor BackgroundSyncController {
    public typealias SleepOperation = @Sendable (Duration) async throws -> Void
    public typealias StateDidChange = @Sendable ([SyncPair], [ActivityEvent]) async -> Void

    private let scheduler: SchedulerService
    private let pairStore: PairStoreControlling
    private let activityStore: ActivityStoreControlling
    private let notificationClient: UserNotificationSending
    private let now: @Sendable () -> Date
    private let sleep: SleepOperation
    private let stateDidChange: StateDidChange

    private var task: Task<Void, Never>?

    public init(
        scheduler: SchedulerService,
        pairStore: PairStoreControlling,
        activityStore: ActivityStoreControlling,
        notificationClient: UserNotificationSending,
        now: @escaping @Sendable () -> Date = Date.init,
        sleep: @escaping SleepOperation = BackgroundSyncController.defaultSleep,
        stateDidChange: @escaping StateDidChange = { _, _ in }
    ) {
        self.scheduler = scheduler
        self.pairStore = pairStore
        self.activityStore = activityStore
        self.notificationClient = notificationClient
        self.now = now
        self.sleep = sleep
        self.stateDidChange = stateDidChange
    }

    public func start() {
        guard task == nil else {
            return
        }

        let controller = self
        let sleep = self.sleep

        task = Task {
            await controller.refreshState()

            while !Task.isCancelled {
                await controller.runCycle()

                do {
                    try await sleep(.seconds(60))
                } catch {
                    break
                }
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
    }

    public func runCycle() async {
        guard let pairs = try? await pairStore.load() else {
            return
        }

        let results = await scheduler.runScheduledPushes(for: pairs, now: now())
        let eventfulResults = results.filter { $0.disposition.recordsActivityEvent }

        guard !eventfulResults.isEmpty else {
            return
        }

        let updatedPairs = results.map(\.pair)

        do {
            try await pairStore.save(updatedPairs)
        } catch {
            return
        }

        for result in eventfulResults {
            let event = makeEvent(for: result, at: now())
            try? await activityStore.append(event)

            if case let .failed(message) = result.disposition {
                try? await notificationClient.send(
                    title: "MacYaD: scheduled sync failed",
                    body: "\(result.pair.name): \(message)"
                )
            }
        }

        await refreshState()
    }

    public func refreshState() async {
        guard let pairs = try? await pairStore.load() else {
            return
        }

        let events = ((try? await activityStore.load()) ?? []).sorted { $0.date > $1.date }
        await stateDidChange(pairs, events)
    }

    public static func defaultSleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }

    private func makeEvent(for result: ScheduledPushResult, at date: Date) -> ActivityEvent {
        let message: String
        let severity: Severity

        switch result.disposition {
        case .pushed:
            message = "Scheduled sync completed"
            severity = .healthy
        case let .failed(errorMessage):
            message = "Scheduled sync failed: \(errorMessage)"
            severity = .alarm
        case .skippedByPolicy, .skippedNotDue:
            message = "Scheduled sync skipped"
            severity = result.pair.lastKnownSeverity
        }

        return ActivityEvent(
            id: UUID(),
            date: date,
            message: message,
            severity: severity,
            pairID: result.pair.id
        )
    }
}
