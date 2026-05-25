import Foundation

public struct PairActivitySeverityResolver: Sendable {
    public init() {}

    public func displaySeverity(for pair: SyncPair, events: [ActivityEvent]) -> Severity {
        events.reduce(pair.lastKnownSeverity) { currentSeverity, event in
            guard event.pairID == pair.id else {
                return currentSeverity
            }

            return max(currentSeverity, event.severity)
        }
    }
}
