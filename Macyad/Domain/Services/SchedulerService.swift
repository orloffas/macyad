import Foundation

public struct SchedulerSnapshot: Sendable {
    public let pairs: [SyncPair]
    public let preferences: AppPreferences

    public init(pairs: [SyncPair], preferences: AppPreferences) {
        self.pairs = pairs
        self.preferences = preferences
    }
}

public typealias SchedulerSnapshotProvider = @Sendable () async -> SchedulerSnapshot

public enum ScheduledSyncDisposition: Equatable, Sendable {
    case synced
    case skippedByPolicy
    case skippedNotDue
    case blocked(summary: String, details: String, issueSet: ActivityIssueSet? = nil)
    case failed(summary: String, details: String, issueSet: ActivityIssueSet? = nil)

    var recordsActivityEvent: Bool {
        switch self {
        case .synced, .blocked, .failed:
            true
        case .skippedByPolicy, .skippedNotDue:
            false
        }
    }
}

public struct ScheduledSyncResult: Equatable, Sendable {
    public var pair: SyncPair
    public var disposition: ScheduledSyncDisposition
    /// Direction that actually ran, so callers can pick the right copy for
    /// activity events and notifications. Nil when nothing ran.
    public var direction: AutoSyncMode?

    public init(pair: SyncPair, disposition: ScheduledSyncDisposition, direction: AutoSyncMode? = nil) {
        self.pair = pair
        self.disposition = disposition
        self.direction = direction
    }
}

public actor SchedulerService {
    public typealias PairsProvider = @Sendable () async -> [SyncPair]
    public typealias SleepOperation = @Sendable (Duration) async throws -> Void
    public typealias SyncServiceProvider = @Sendable () async throws -> SyncService

    private var task: Task<Void, Never>?
    private let policy: ScheduledSyncEligibilityPolicy
    private let syncServiceProvider: SyncServiceProvider
    private let sleep: SleepOperation
    private let operationCoordinator: SerialOperationCoordinator?

    public init(
        policy: ScheduledSyncEligibilityPolicy,
        syncService: SyncService,
        operationCoordinator: SerialOperationCoordinator? = nil,
        sleep: @escaping SleepOperation = SchedulerService.defaultSleep
    ) {
        self.init(
            policy: policy,
            syncServiceProvider: { syncService },
            operationCoordinator: operationCoordinator,
            sleep: sleep
        )
    }

    public init(
        policy: ScheduledSyncEligibilityPolicy = ScheduledSyncEligibilityPolicy(),
        syncServiceProvider: @escaping SyncServiceProvider,
        operationCoordinator: SerialOperationCoordinator? = nil,
        sleep: @escaping SleepOperation = SchedulerService.defaultSleep
    ) {
        self.policy = policy
        self.syncServiceProvider = syncServiceProvider
        self.operationCoordinator = operationCoordinator
        self.sleep = sleep
    }

    public func start(with pairsProvider: @escaping PairsProvider) {
        task?.cancel()
        let scheduler = self
        task = Task {
            while !Task.isCancelled {
                _ = await scheduler.runScheduledSyncs(for: await pairsProvider(), now: Date())

                do {
                    try await scheduler.sleep(.seconds(60))
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

    public func runScheduledSyncs(
        snapshot: SchedulerSnapshot,
        now: Date = Date(),
        lifecycle: ScheduledSyncLifecycle = .noop
    ) async -> [ScheduledSyncResult] {
        guard !snapshot.preferences.isGlobalSchedulerPaused else {
            return snapshot.pairs.map { ScheduledSyncResult(pair: $0, disposition: .skippedByPolicy) }
        }
        return await runScheduledSyncs(for: snapshot.pairs, now: now, lifecycle: lifecycle)
    }

    func runScheduledSyncs(
        for pairs: [SyncPair],
        now: Date = Date(),
        lifecycle: ScheduledSyncLifecycle = .noop
    ) async -> [ScheduledSyncResult] {
        let copy = AppCopy.current
        let dueEligiblePairs = pairs.filter { policy.canRunScheduledSync(for: $0) && isDue($0, now: now) }

        let syncService: SyncService?
        let syncServiceError: Error?

        if dueEligiblePairs.isEmpty {
            syncService = nil
            syncServiceError = nil
        } else {
            do {
                syncService = try await syncServiceProvider()
                syncServiceError = nil
            } catch {
                syncService = nil
                syncServiceError = error
            }
        }

        var results: [ScheduledSyncResult] = []
        results.reserveCapacity(pairs.count)

        for pair in pairs {
            guard policy.canRunScheduledSync(for: pair) else {
                results.append(ScheduledSyncResult(pair: pair, disposition: .skippedByPolicy))
                continue
            }

            // The policy already rejected `.off`, so this is push or pull.
            let direction = pair.autoSyncMode
            let isPull = direction == .pull

            guard isDue(pair, now: now) else {
                results.append(ScheduledSyncResult(pair: pair, disposition: .skippedNotDue))
                continue
            }

            var updatedPair = pair
            updatedPair.lastScheduledSyncAttemptAt = now

            guard let syncService else {
                updatedPair.lastKnownSeverity = .alarm
                results.append(ScheduledSyncResult(
                    pair: updatedPair,
                    disposition: .failed(
                        summary: syncServiceError?.localizedDescription ?? copy.scheduledSyncBootstrapFailure(direction),
                        details: syncServiceError?.localizedDescription ?? copy.scheduledSyncBootstrapFailure(direction),
                        issueSet: nil
                    ),
                    direction: direction
                ))
                continue
            }

            let observer = await lifecycle.willStart(pair)
            let run: @Sendable () async -> SyncService.OperationOutcome = {
                if isPull {
                    await syncService.pull(pair, executionMode: .scheduled, observer: observer)
                } else {
                    await syncService.push(pair, executionMode: .scheduled, observer: observer)
                }
            }

            let outcome: SyncService.OperationOutcome
            if let operationCoordinator {
                do {
                    outcome = try await operationCoordinator.enqueue(
                        pairID: pair.id,
                        label: "scheduled-\(direction.rawValue)",
                        operation: run
                    )
                } catch {
                    outcome = SyncService.OperationOutcome(
                        severity: .alarm,
                        summary: error.localizedDescription,
                        details: error.localizedDescription
                    )
                }
            } else {
                outcome = await run()
            }
            await lifecycle.didFinish(pair)
            switch outcome.severity {
            case .healthy:
                updatedPair.lastKnownSeverity = .healthy
                if outcome.shouldUpdateLastSync {
                    updatedPair.lastSyncAt = now
                }
                results.append(ScheduledSyncResult(pair: updatedPair, disposition: .synced, direction: direction))
            case .warning:
                updatedPair.lastKnownSeverity = .warning
                results.append(ScheduledSyncResult(
                    pair: updatedPair,
                    disposition: .blocked(
                        summary: outcome.summary,
                        details: outcome.details ?? outcome.summary,
                        issueSet: outcome.issueSet
                    ),
                    direction: direction
                ))
            case .info, .alarm:
                updatedPair.lastKnownSeverity = .alarm
                results.append(ScheduledSyncResult(
                    pair: updatedPair,
                    disposition: .failed(
                        summary: outcome.summary,
                        details: outcome.details ?? outcome.summary,
                        issueSet: outcome.issueSet
                    ),
                    direction: direction
                ))
            }
        }

        return results
    }

    public static func defaultSleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }

    private func isDue(_ pair: SyncPair, now: Date) -> Bool {
        guard let lastScheduledReferenceAt = pair.nextScheduledReferenceAt else {
            return true
        }

        return now.timeIntervalSince(lastScheduledReferenceAt) >= Double(pair.scheduleMinutes * 60)
    }
}
