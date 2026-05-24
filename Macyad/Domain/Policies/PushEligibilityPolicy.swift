public struct PushEligibilityPolicy: Sendable {
    public init() {}

    public func canRunScheduledPush(for pair: SyncPair) -> Bool {
        pair.lastKnownSeverity != .alarm
    }
}
