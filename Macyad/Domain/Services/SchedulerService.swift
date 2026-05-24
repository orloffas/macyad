import Foundation

public enum ScheduledPushDisposition: Equatable, Sendable {
    case pushed
    case skippedByPolicy
    case skippedNotDue
    case failed(String)

    var recordsActivityEvent: Bool {
        switch self {
        case .pushed, .failed:
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

    public init(
        policy: PushEligibilityPolicy,
        syncService: SyncService,
        sleep: @escaping SleepOperation = SchedulerService.defaultSleep
    ) {
        self.init(
            policy: policy,
            syncServiceProvider: { syncService },
            sleep: sleep
        )
    }

    public init(
        policy: PushEligibilityPolicy = PushEligibilityPolicy(),
        syncServiceProvider: @escaping SyncServiceProvider,
        sleep: @escaping SleepOperation = SchedulerService.defaultSleep
    ) {
        self.policy = policy
        self.syncServiceProvider = syncServiceProvider
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

    public func runScheduledPushes(for pairs: [SyncPair], now: Date = Date()) async -> [ScheduledPushResult] {
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

            guard let syncService else {
                updatedPair.lastKnownSeverity = .alarm
                results.append(ScheduledPushResult(
                    pair: updatedPair,
                    disposition: .failed(syncServiceError?.localizedDescription ?? "Не удалось инициализировать scheduled sync.")
                ))
                continue
            }

            do {
                try await syncService.push(pair)
                updatedPair.lastKnownSeverity = .healthy
                updatedPair.lastSyncAt = now
                results.append(ScheduledPushResult(pair: updatedPair, disposition: .pushed))
            } catch {
                updatedPair.lastKnownSeverity = .alarm
                results.append(ScheduledPushResult(pair: updatedPair, disposition: .failed(error.localizedDescription)))
            }
        }

        return results
    }

    public static func defaultSleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }

    private func isDue(_ pair: SyncPair, now: Date) -> Bool {
        guard let lastSyncAt = pair.lastSyncAt else {
            return true
        }

        return now.timeIntervalSince(lastSyncAt) >= Double(pair.scheduleMinutes * 60)
    }
}
