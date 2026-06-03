import Foundation

public struct OverviewPairRow: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let severity: Severity
    public let lastSyncTitle: String
    public let isAutoPushEnabled: Bool
    public let isGloballyPaused: Bool

    public var isPaused: Bool {
        isGloballyPaused || !isAutoPushEnabled
    }
}

@MainActor
public final class OverviewViewModel: ObservableObject {
    @Published public private(set) var rows: [OverviewPairRow] = []

    public init() {}

    public func update(pairs: [SyncPair], events: [ActivityEvent], preferences: AppPreferences, copy: AppCopy) {
        rows = pairs.map { pair in
            let latestEvent = events
                .filter { $0.pairID == pair.id }
                .max(by: { $0.date < $1.date })

            let severity = latestEvent.map(\.severity) ?? pair.lastKnownSeverity

            let lastSyncTitle: String
            if let date = pair.lastSyncAt {
                lastSyncTitle = copy.formatTimestamp(date)
            } else {
                lastSyncTitle = copy.neverSynced
            }

            return OverviewPairRow(
                id: pair.id,
                name: pair.name,
                severity: severity,
                lastSyncTitle: lastSyncTitle,
                isAutoPushEnabled: pair.isAutoPushEnabled,
                isGloballyPaused: preferences.isGlobalSchedulerPaused
            )
        }
    }
}
