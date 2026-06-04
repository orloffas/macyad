import Foundation

public protocol PairStoreControlling: Sendable {
    func load() async throws -> [SyncPair]
    func save(_ pairs: [SyncPair]) async throws
}

public protocol ActivityStoreControlling: Sendable {
    func load() async throws -> [ActivityEvent]
    func append(_ event: ActivityEvent) async throws
}

public protocol PreferencesStoreControlling: Sendable {
    func load() async throws -> AppPreferences
}

extension PairRepository: PairStoreControlling {}
extension ActivityRepository: ActivityStoreControlling {}
extension AppPreferencesStore: PreferencesStoreControlling {}
extension UserNotificationClient: UserNotificationSending {}

public actor BackgroundSyncController {
    public typealias SleepOperation = @Sendable (Duration) async throws -> Void
    public typealias StateDidChange = @Sendable ([SyncPair], [ActivityEvent]) async -> Void

    private let scheduler: SchedulerService
    private let pairStore: PairStoreControlling
    private let preferencesStore: PreferencesStoreControlling
    private let activityStore: ActivityStoreControlling
    private let notificationClient: UserNotificationSending
    private let now: @Sendable () -> Date
    private let sleep: SleepOperation
    private let stateDidChange: StateDidChange
    private let scheduledPushLifecycle: ScheduledPushLifecycle

    private var task: Task<Void, Never>?

    public init(
        scheduler: SchedulerService,
        pairStore: PairStoreControlling,
        preferencesStore: PreferencesStoreControlling,
        activityStore: ActivityStoreControlling,
        notificationClient: UserNotificationSending,
        now: @escaping @Sendable () -> Date = Date.init,
        sleep: @escaping SleepOperation = BackgroundSyncController.defaultSleep,
        stateDidChange: @escaping StateDidChange = { _, _ in },
        scheduledPushLifecycle: ScheduledPushLifecycle = .noop
    ) {
        self.scheduler = scheduler
        self.pairStore = pairStore
        self.preferencesStore = preferencesStore
        self.activityStore = activityStore
        self.notificationClient = notificationClient
        self.now = now
        self.sleep = sleep
        self.stateDidChange = stateDidChange
        self.scheduledPushLifecycle = scheduledPushLifecycle
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
                do {
                    try await sleep(.seconds(60))
                } catch {
                    break
                }

                await controller.runCycle()
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
    }

    public func runCycle() async {
        let copy = AppCopy.current

        guard let pairs = try? await pairStore.load() else {
            return
        }

        let preferences = (try? await preferencesStore.load()) ?? .defaults
        let snapshot = SchedulerSnapshot(pairs: pairs, preferences: preferences)
        let results = await scheduler.runScheduledPushes(snapshot: snapshot, now: now(), lifecycle: scheduledPushLifecycle)
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

            if case let .blocked(summary, _, _) = result.disposition {
                try? await notificationClient.send(
                    title: copy.pushBlockedNotificationTitle,
                    body: "\(result.pair.name): \(summary)",
                    routeToken: event.routeToken
                )
            } else if case let .failed(summary, _, _) = result.disposition {
                try? await notificationClient.send(
                    title: copy.scheduledSyncNotificationTitle,
                    body: "\(result.pair.name): \(summary)",
                    routeToken: event.routeToken
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
        let copy = AppCopy.current
        let message: String
        let severity: Severity
        let eventID = UUID()
        let routeToken: ActivityRouteToken?
        let issueSet: ActivityIssueSet?

        switch result.disposition {
        case .pushed:
            message = copy.scheduledSyncCompleted
            severity = .healthy
            routeToken = nil
            issueSet = nil
        case .blocked:
            message = copy.scheduledPushBlockedTitle
            severity = .warning
            routeToken = ActivityRouteToken(pairID: result.pair.id, eventID: eventID, openIssueTable: result.disposition.issueSet != nil)
            issueSet = result.disposition.issueSet
            return ActivityEvent(
                id: eventID,
                date: date,
                message: message,
                severity: severity,
                pairID: result.pair.id,
                details: result.disposition.details,
                issueSet: issueSet,
                routeToken: routeToken
            )
        case let .failed(summary, _, _):
            message = copy.scheduledSyncFailed(summary)
            severity = .alarm
            routeToken = ActivityRouteToken(pairID: result.pair.id, eventID: eventID, openIssueTable: result.disposition.issueSet != nil)
            issueSet = result.disposition.issueSet
        case .skippedByPolicy, .skippedNotDue:
            message = copy.scheduledSyncSkipped
            severity = result.pair.lastKnownSeverity
            routeToken = nil
            issueSet = nil
        }

        return ActivityEvent(
            id: eventID,
            date: date,
            message: message,
            severity: severity,
            pairID: result.pair.id,
            details: result.disposition.details,
            issueSet: issueSet,
            routeToken: routeToken
        )
    }
}

private extension ScheduledPushDisposition {
    var details: String? {
        switch self {
        case let .failed(_, details, _), let .blocked(_, details, _):
            details
        case .pushed, .skippedByPolicy, .skippedNotDue:
            nil
        }
    }

    var issueSet: ActivityIssueSet? {
        switch self {
        case let .failed(_, _, issueSet), let .blocked(_, _, issueSet):
            issueSet
        case .pushed, .skippedByPolicy, .skippedNotDue:
            nil
        }
    }
}
