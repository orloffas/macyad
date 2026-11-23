public struct ScheduledSyncEligibilityPolicy: Sendable {
    public init() {}

    public func canRunScheduledSync(for pair: SyncPair) -> Bool {
        // An alarm waits for a person, unless only the network failed: that heals by itself.
        pair.autoSyncMode != .off && (pair.lastKnownSeverity != .alarm || pair.lastFailureIsTransient)
    }
}
