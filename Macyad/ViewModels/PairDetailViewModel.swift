import Foundation
import Combine

@MainActor
public final class PairDetailViewModel: ObservableObject {
    @Published public private(set) var latestSeverity: Severity = .healthy
    @Published public private(set) var events: [ActivityEvent] = []
    @Published public private(set) var isRunningOperation = false
    @Published public private(set) var lastErrorMessage: String?

    private let activityRepository: ActivityRepository

    public init(activityRepository: ActivityRepository) {
        self.activityRepository = activityRepository
    }

    public func load(for pair: SyncPair?) async {
        latestSeverity = pair?.lastKnownSeverity ?? .healthy
        guard let pair else {
            events = []
            lastErrorMessage = nil
            return
        }

        do {
            events = try await activityRepository.events(for: pair.id)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func setOperationInFlight(_ isRunning: Bool) {
        isRunningOperation = isRunning
    }

    public func setError(_ message: String?) {
        lastErrorMessage = message
    }

    public func record(_ event: ActivityEvent, latestSeverity: Severity) async {
        do {
            try await activityRepository.append(event)
            events = try await activityRepository.events(for: event.pairID)
            self.latestSeverity = latestSeverity
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}
