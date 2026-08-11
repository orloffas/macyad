import Foundation

public protocol PairStoreControlling: Sendable {
    func load() async throws -> [SyncPair]
    func save(_ pairs: [SyncPair]) async throws
}

public protocol ActivityStoreControlling: Sendable {
    func load() async throws -> [ActivityEvent]
    func append(_ event: ActivityEvent) async throws
    func replace(_ event: ActivityEvent) async throws
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
    private let scheduledSyncLifecycle: ScheduledSyncLifecycle

    private var task: Task<Void, Never>?
    /// Journal entry written when a scheduled sync starts, keyed by pair, so
    /// the result can replace it instead of adding a second entry.
    private var inFlightEventIDs: [UUID: UUID] = [:]

    public init(
        scheduler: SchedulerService,
        pairStore: PairStoreControlling,
        preferencesStore: PreferencesStoreControlling,
        activityStore: ActivityStoreControlling,
        notificationClient: UserNotificationSending,
        now: @escaping @Sendable () -> Date = Date.init,
        sleep: @escaping SleepOperation = BackgroundSyncController.defaultSleep,
        stateDidChange: @escaping StateDidChange = { _, _ in },
        scheduledSyncLifecycle: ScheduledSyncLifecycle = .noop
    ) {
        self.scheduler = scheduler
        self.pairStore = pairStore
        self.preferencesStore = preferencesStore
        self.activityStore = activityStore
        self.notificationClient = notificationClient
        self.now = now
        self.sleep = sleep
        self.stateDidChange = stateDidChange
        self.scheduledSyncLifecycle = scheduledSyncLifecycle
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
        let results = await scheduler.runScheduledSyncs(snapshot: snapshot, now: now(), lifecycle: instrumentedLifecycle())
        let eventfulResults = results.filter { $0.disposition.recordsActivityEvent }

        guard !eventfulResults.isEmpty else {
            return
        }

        let updatedPairs = results.map(\.pair)

        // A failed save must not skip the journal: rclone has already run, and
        // returning here would leave the entry written at start claiming to be
        // running until the next launch.
        try? await pairStore.save(updatedPairs)

        for result in eventfulResults {
            let event = makeEvent(for: result, at: now(), eventID: inFlightEventIDs.removeValue(forKey: result.pair.id) ?? UUID())
            // `replace` also appends when there is nothing to replace, which is
            // the case for runs that failed before they ever started (no rclone
            // binary, say) — those never reach `willStart`.
            try? await activityStore.replace(event)
            let direction = result.direction ?? result.pair.autoSyncMode

            if case let .blocked(summary, _, _) = result.disposition {
                try? await notificationClient.send(
                    title: copy.syncBlockedNotificationTitle(direction),
                    body: "\(result.pair.name): \(summary)",
                    routeToken: event.routeToken
                )
            } else if case let .failed(summary, _, _) = result.disposition {
                try? await notificationClient.send(
                    title: copy.scheduledSyncNotificationTitle(direction),
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

    /// Wraps the caller's lifecycle so every scheduled run leaves a journal
    /// entry the moment it starts. A run interrupted by a quit — a mirroring
    /// push may already have deleted files on the remote by then — would
    /// otherwise vanish without a trace, since the result event is written
    /// only after the whole cycle returns.
    private func instrumentedLifecycle() -> ScheduledSyncLifecycle {
        let base = scheduledSyncLifecycle

        return ScheduledSyncLifecycle(
            willStart: { [self] pair in
                await recordScheduledSyncStart(for: pair)
                return await base.willStart(pair)
            },
            didFinish: { pair in
                await base.didFinish(pair)
            }
        )
    }

    private func recordScheduledSyncStart(for pair: SyncPair) async {
        let copy = AppCopy.current
        let operationName = copy.scheduledSyncOperationName(pair.autoSyncMode)
        let eventID = UUID()
        inFlightEventIDs[pair.id] = eventID

        let event = ActivityEvent(
            id: eventID,
            date: now(),
            message: copy.operationStartedMessage(operationName),
            severity: .info,
            pairID: pair.id,
            inFlightOperation: operationName
        )
        try? await activityStore.append(event)
        await refreshState()
    }

    private func makeEvent(for result: ScheduledSyncResult, at date: Date, eventID: UUID) -> ActivityEvent {
        let copy = AppCopy.current
        let direction = result.direction ?? result.pair.autoSyncMode
        let message: String
        let severity: Severity
        let routeToken: ActivityRouteToken?
        let issueSet: ActivityIssueSet?

        switch result.disposition {
        case .synced:
            message = copy.scheduledSyncCompleted(direction)
            severity = .healthy
            routeToken = nil
            issueSet = nil
        case .blocked:
            message = copy.scheduledSyncBlockedTitle(direction)
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
            message = copy.scheduledSyncFailed(summary, direction: direction)
            severity = .alarm
            routeToken = ActivityRouteToken(pairID: result.pair.id, eventID: eventID, openIssueTable: result.disposition.issueSet != nil)
            issueSet = result.disposition.issueSet
        case .skippedByPolicy, .skippedNotDue:
            message = copy.scheduledSyncSkipped(direction)
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

private extension ScheduledSyncDisposition {
    var details: String? {
        switch self {
        case let .failed(_, details, _), let .blocked(_, details, _):
            details
        case .synced, .skippedByPolicy, .skippedNotDue:
            nil
        }
    }

    var issueSet: ActivityIssueSet? {
        switch self {
        case let .failed(_, _, issueSet), let .blocked(_, _, issueSet):
            issueSet
        case .synced, .skippedByPolicy, .skippedNotDue:
            nil
        }
    }
}
