import Foundation
import Combine

@MainActor
public final class PairDetailViewModel: ObservableObject {
    public enum OperationPhase: Equatable {
        case idle
        case queued
        case running
    }

    @Published public private(set) var latestSeverity: Severity = .healthy
    @Published public private(set) var operationPhase: OperationPhase = .idle
    @Published public private(set) var lastErrorMessage: String?

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

    public func setOperationPhase(_ phase: OperationPhase) {
        operationPhase = phase
    }

    public func setLatestSeverity(_ severity: Severity) {
        latestSeverity = severity
    }

    public func setError(_ message: String?) {
        lastErrorMessage = message
    }
}
