import Foundation

public enum ScheduledPushDisposition: Equatable, Sendable {
    case pushed
    case skippedByPolicy
    case skippedNotDue
    case blockedEmptyLocalFolder(summary: String, details: String)
    case failed(summary: String, details: String)

    var recordsActivityEvent: Bool {
        switch self {
        case .pushed, .blockedEmptyLocalFolder, .failed:
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

            guard let syncService else {
                updatedPair.lastKnownSeverity = .alarm
                results.append(ScheduledPushResult(
                    pair: updatedPair,
                    disposition: .failed(
                        summary: syncServiceError?.localizedDescription ?? copy.scheduledSyncBootstrapFailure,
                        details: detailedMessage(for: syncServiceError, copy: copy) ?? copy.scheduledSyncBootstrapFailure
                    )
                ))
                continue
            }

            do {
                try await syncService.push(pair)
                updatedPair.lastKnownSeverity = .healthy
                updatedPair.lastSyncAt = now
                results.append(ScheduledPushResult(pair: updatedPair, disposition: .pushed))
            } catch let error as SyncService.LocalFolderEmptyPushBlockedError {
                updatedPair.lastKnownSeverity = .warning
                results.append(ScheduledPushResult(
                    pair: updatedPair,
                    disposition: .blockedEmptyLocalFolder(
                        summary: error.localizedDescription,
                        details: error.localizedDescription
                    )
                ))
            } catch {
                updatedPair.lastKnownSeverity = .alarm
                results.append(ScheduledPushResult(
                    pair: updatedPair,
                    disposition: .failed(
                        summary: error.localizedDescription,
                        details: detailedMessage(for: error, copy: copy) ?? error.localizedDescription
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
        guard let lastSyncAt = pair.lastSyncAt else {
            return true
        }

        return now.timeIntervalSince(lastSyncAt) >= Double(pair.scheduleMinutes * 60)
    }

    private func detailedMessage(for error: Error?, copy: AppCopy) -> String? {
        guard let error else {
            return nil
        }

        if let commandError = error as? SyncService.CommandFailedError {
            return commandError.detailedDescription
        }

        return error.localizedDescription
    }
}
