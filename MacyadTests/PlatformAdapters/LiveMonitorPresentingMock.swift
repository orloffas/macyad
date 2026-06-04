import Foundation
@testable import MacyadCore

@MainActor
final class LiveMonitorPresentingMock: LiveMonitorPresenting {
    private(set) var openedWindows: [UUID] = []
    private(set) var viewModels: [UUID: LiveMonitorViewModel] = [:]

    func ensureViewModel(for pairID: UUID) -> LiveMonitorViewModel {
        if let existing = viewModels[pairID] { return existing }
        let fresh = LiveMonitorViewModel()
        viewModels[pairID] = fresh
        return fresh
    }

    func viewModel(for pairID: UUID) -> LiveMonitorViewModel? {
        viewModels[pairID]
    }

    func hasLog(for pairID: UUID) -> Bool {
        viewModels[pairID] != nil
    }

    func present(pair: SyncPair, copy: AppCopy) {
        _ = ensureViewModel(for: pair.id)
        if openedWindows.contains(pair.id) { return }
        openedWindows.append(pair.id)
    }

    func close(pairID: UUID) {
        openedWindows.removeAll { $0 == pairID }
        // viewModels persists across close so reopen retains the captured log
    }
}
