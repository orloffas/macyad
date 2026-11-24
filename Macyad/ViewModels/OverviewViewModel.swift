import Foundation

public enum OverviewPauseSource: Sendable, Equatable {
    case none
    case global
    case perPair
}

public struct OverviewPairRow: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let severity: Severity
    public let lastSyncTitle: String
    public let autoSyncMode: AutoSyncMode
    public let isGloballyPaused: Bool
    public let pauseSource: OverviewPauseSource

    public var isPaused: Bool {
        pauseSource != .none
    }
}

@MainActor
public final class OverviewViewModel: ObservableObject {
    @Published public private(set) var rows: [OverviewPairRow] = []

    public init() {}

    /// Pairs that "Push All" / "Check All" queue, in list order. A pair already running is left
    /// alone. Push runs only Auto-Push pairs: Auto-Pull pairs take Yandex as their source, and
    /// an Off pair is shown as "Paused (this pair)" — somebody stopped it on purpose. Check
    /// changes nothing, so it covers every pair.
    public static func bulkRunPairs(_ pairs: [SyncPair], push: Bool, busy: Set<UUID>) -> [SyncPair] {
        pairs.filter { !busy.contains($0.id) && (!push || $0.autoSyncMode == .push) }
    }

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

            let pauseSource: OverviewPauseSource
            if preferences.isGlobalSchedulerPaused {
                pauseSource = .global
            } else if pair.autoSyncMode == .off {
                pauseSource = .perPair
            } else {
                pauseSource = .none
            }

            return OverviewPairRow(
                id: pair.id,
                name: pair.name,
                severity: severity,
                lastSyncTitle: lastSyncTitle,
                autoSyncMode: pair.autoSyncMode,
                isGloballyPaused: preferences.isGlobalSchedulerPaused,
                pauseSource: pauseSource
            )
        }
    }
}
