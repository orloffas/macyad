import Foundation
import Combine

@MainActor
public final class PairDetailViewModel: ObservableObject {
    public enum OperationPhase: Equatable {
        case idle
        case queued
        case running
    }

    public enum PauseSource: Sendable {
        case none
        case global
        case perPair
    }

    @Published public private(set) var latestSeverity: Severity = .healthy
    // Keyed by pair: one shared phase showed pair A's queued Push on pair B's card, and the
    // first run to finish cleared the indicator of runs still waiting behind it.
    @Published private var operationPhases: [UUID: OperationPhase] = [:]
    @Published private var lastOperationKinds: [UUID: SyncService.ExecutionMode] = [:]
    @Published public private(set) var lastErrorMessage: String?

    public var onChangeAutoSyncMode: ((SyncPair, AutoSyncMode) async -> Void)?

    public init() {}

    public func load(for pair: SyncPair?) async {
        latestSeverity = pair?.lastKnownSeverity ?? .healthy
        guard pair != nil else {
            lastErrorMessage = nil
            return
        }
    }

    public func operationPhase(for pairID: UUID?) -> OperationPhase {
        pairID.flatMap { operationPhases[$0] } ?? .idle
    }

    public func lastOperationKind(for pairID: UUID?) -> SyncService.ExecutionMode? {
        pairID.flatMap { lastOperationKinds[$0] }
    }

    public func setOperationPhase(_ phase: OperationPhase, for pairID: UUID, kind: SyncService.ExecutionMode? = nil) {
        operationPhases[pairID] = phase == .idle ? nil : phase
        if let kind {
            lastOperationKinds[pairID] = kind
        }
    }

    public func setLatestSeverity(_ severity: Severity) {
        latestSeverity = severity
    }

    public func setError(_ message: String?) {
        lastErrorMessage = message
    }

    public enum NextSync: Equatable {
        case paused
        /// An alarm the scheduler will not retry: nothing runs until somebody starts the pair.
        case afterManualRun
        case afterFirstSync
        case at(Date)
    }

    /// Mirrors the scheduler's own rule, so the card never promises a run that will not happen.
    public func nextSync(for pair: SyncPair, preferences: AppPreferences) -> NextSync {
        if pauseSource(for: pair, preferences: preferences) != .none { return .paused }
        if !ScheduledSyncEligibilityPolicy().canRunScheduledSync(for: pair) { return .afterManualRun }
        guard let reference = pair.nextScheduledReferenceAt else { return .afterFirstSync }
        return .at(reference.addingTimeInterval(TimeInterval(pair.scheduleMinutes * 60)))
    }

    public func pauseSource(for pair: SyncPair, preferences: AppPreferences) -> PauseSource {
        if preferences.isGlobalSchedulerPaused { return .global }
        if pair.autoSyncMode == .off { return .perPair }
        return .none
    }
}
