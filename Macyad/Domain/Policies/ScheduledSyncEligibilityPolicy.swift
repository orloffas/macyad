public struct ScheduledSyncEligibilityPolicy: Sendable {
    public init() {}

    public func canRunScheduledSync(for pair: SyncPair) -> Bool {
        pair.autoSyncMode != .off && pair.lastKnownSeverity != .alarm
    }
}
