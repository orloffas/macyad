import Foundation
@testable import MacyadCore

@MainActor
final class LiveMonitorPresentingMock: LiveMonitorPresenting {
    private(set) var openedWindows: [UUID] = []
    private(set) var viewModels: [UUID: LiveMonitorViewModel] = [:]
    private(set) var lastRestartIfExisting: [UUID: Bool] = [:]

    func present(pair: SyncPair, viewModel: LiveMonitorViewModel, copy: AppCopy, restartIfExisting: Bool) {
        lastRestartIfExisting[pair.id] = restartIfExisting
        if openedWindows.contains(pair.id) { return }
        openedWindows.append(pair.id)
        viewModels[pair.id] = viewModel
    }

    func close(pairID: UUID) {
        openedWindows.removeAll { $0 == pairID }
        viewModels.removeValue(forKey: pairID)
    }
}
