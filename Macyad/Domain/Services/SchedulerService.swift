import Foundation

public actor SchedulerService {
    public typealias PairsProvider = @Sendable () async -> [SyncPair]
    public typealias SleepOperation = @Sendable (Duration) async throws -> Void

    private var task: Task<Void, Never>?
    private let policy: PushEligibilityPolicy
    private let syncService: SyncService
    private let sleep: SleepOperation

    public init(
        policy: PushEligibilityPolicy,
        syncService: SyncService,
        sleep: @escaping SleepOperation = SchedulerService.defaultSleep
    ) {
        self.policy = policy
        self.syncService = syncService
        self.sleep = sleep
    }

    public func start(with pairsProvider: @escaping PairsProvider) {
        task?.cancel()
        task = Task {
            while !Task.isCancelled {
                _ = await runScheduledPushes(for: await pairsProvider())

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

    public func runScheduledPushes(for pairs: [SyncPair]) async -> [UUID] {
        var executedPairIDs: [UUID] = []

        for pair in pairs where policy.canRunScheduledPush(for: pair) {
            do {
                try await syncService.push(pair)
                executedPairIDs.append(pair.id)
            } catch {
                continue
            }
        }

        return executedPairIDs
    }

    public static func defaultSleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}
