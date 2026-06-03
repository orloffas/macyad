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

public enum ScheduledPushDisposition: Equatable, Sendable {
    case pushed
    case skippedByPolicy
    case skippedNotDue
    case blocked(summary: String, details: String, issueSet: ActivityIssueSet? = nil)
    case failed(summary: String, details: String, issueSet: ActivityIssueSet? = nil)

    var recordsActivityEvent: Bool {
        switch self {
        case .pushed, .blocked, .failed:
            true
        case .skippedByPolicy, .skippedNotDue:
            false
        }
    }
}

public struct ScheduledPushResult: Equatable, Sendable {
    public var pair: SyncPair
    public var disposition: ScheduledPushDisposition

    public init(pair: SyncPair, disposition: ScheduledPushDisposition) {
        self.pair = pair
        self.disposition = disposition
    }
}

public actor SchedulerService {
    public typealias PairsProvider = @Sendable () async -> [SyncPair]
    public typealias SleepOperation = @Sendable (Duration) async throws -> Void
    public typealias SyncServiceProvider = @Sendable () async throws -> SyncService

    private var task: Task<Void, Never>?
    private let policy: PushEligibilityPolicy
    private let syncServiceProvider: SyncServiceProvider
    private let sleep: SleepOperation
    private let operationCoordinator: SerialOperationCoordinator?

    public init(
        policy: PushEligibilityPolicy,
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
        policy: PushEligibilityPolicy = PushEligibilityPolicy(),
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
                _ = await scheduler.runScheduledPushes(for: await pairsProvider(), now: Date())

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

    public func runScheduledPushes(snapshot: SchedulerSnapshot, now: Date = Date()) async -> [ScheduledPushResult] {
        guard !snapshot.preferences.isGlobalSchedulerPaused else {
            return snapshot.pairs.map { ScheduledPushResult(pair: $0, disposition: .skippedByPolicy) }
        }
        return await runScheduledPushes(for: snapshot.pairs, now: now)
    }

    func runScheduledPushes(for pairs: [SyncPair], now: Date = Date()) async -> [ScheduledPushResult] {
        let copy = AppCopy.current
        let dueEligiblePairs = pairs.filter { policy.canRunScheduledPush(for: $0) && isDue($0, now: now) }

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

        var results: [ScheduledPushResult] = []
        results.reserveCapacity(pairs.count)

        for pair in pairs {
            guard policy.canRunScheduledPush(for: pair) else {
                results.append(ScheduledPushResult(pair: pair, disposition: .skippedByPolicy))
                continue
            }

            guard isDue(pair, now: now) else {
                results.append(ScheduledPushResult(pair: pair, disposition: .skippedNotDue))
                continue
            }

            var updatedPair = pair
            updatedPair.lastScheduledPushAttemptAt = now

            guard let syncService else {
                updatedPair.lastKnownSeverity = .alarm
                results.append(ScheduledPushResult(
                    pair: updatedPair,
                    disposition: .failed(
                        summary: syncServiceError?.localizedDescription ?? copy.scheduledSyncBootstrapFailure,
                        details: syncServiceError?.localizedDescription ?? copy.scheduledSyncBootstrapFailure,
                        issueSet: nil
                    )
                ))
                continue
            }

            let outcome: SyncService.OperationOutcome
            if let operationCoordinator {
                do {
                    outcome = try await operationCoordinator.enqueue(pairID: pair.id, label: "scheduled-push") {
                        await syncService.push(pair, executionMode: .scheduled)
                    }
                } catch {
                    outcome = SyncService.OperationOutcome(
                        severity: .alarm,
                        summary: error.localizedDescription,
                        details: error.localizedDescription
                    )
                }
            } else {
                outcome = await syncService.push(pair, executionMode: .scheduled)
            }
            switch outcome.severity {
            case .healthy:
                updatedPair.lastKnownSeverity = .healthy
                if outcome.shouldUpdateLastSync {
                    updatedPair.lastSyncAt = now
                }
                results.append(ScheduledPushResult(pair: updatedPair, disposition: .pushed))
            case .warning:
                updatedPair.lastKnownSeverity = .warning
                results.append(ScheduledPushResult(
                    pair: updatedPair,
                    disposition: .blocked(
                        summary: outcome.summary,
                        details: outcome.details ?? outcome.summary,
                        issueSet: outcome.issueSet
                    )
                ))
            case .info, .alarm:
                updatedPair.lastKnownSeverity = .alarm
                results.append(ScheduledPushResult(
                    pair: updatedPair,
                    disposition: .failed(
                        summary: outcome.summary,
                        details: outcome.details ?? outcome.summary,
                        issueSet: outcome.issueSet
                    )
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
