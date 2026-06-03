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
    @Published public private(set) var operationPhase: OperationPhase = .idle
    @Published public private(set) var lastOperationKind: SyncService.ExecutionMode?
    @Published public private(set) var lastErrorMessage: String?

    public var onToggleAutoPush: ((SyncPair, Bool) async -> Void)?

    public init() {}

    public func load(for pair: SyncPair?) async {
        latestSeverity = pair?.lastKnownSeverity ?? .healthy
        guard pair != nil else {
            lastErrorMessage = nil
            operationPhase = .idle
            return
        }
    }

    public func setOperationInFlight(_ isRunning: Bool) {
        operationPhase = isRunning ? .running : .idle
    }

    public func setOperationPhase(_ phase: OperationPhase, kind: SyncService.ExecutionMode? = nil) {
        operationPhase = phase
        if let kind {
            lastOperationKind = kind
        }
    }

    public func setLatestSeverity(_ severity: Severity) {
        latestSeverity = severity
    }

    public func setError(_ message: String?) {
        lastErrorMessage = message
    }

    public func pauseSource(for pair: SyncPair, preferences: AppPreferences) -> PauseSource {
        if preferences.isGlobalSchedulerPaused { return .global }
        if !pair.isAutoPushEnabled { return .perPair }
        return .none
    }
}
