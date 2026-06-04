import Foundation
@testable import MacyadCore

@MainActor
final class LiveMonitorPresentingMock: LiveMonitorPresenting {
    private(set) var runningViewModels: [UUID: LiveMonitorViewModel] = [:]
    private(set) var archivedViewModels: [UUID: LiveMonitorViewModel] = [:]
    private(set) var openedWindows: [UUID: Set<LiveMonitorSlot>] = [:]

    func ensureRunningViewModel(for pairID: UUID) -> LiveMonitorViewModel {
        if let existing = runningViewModels[pairID] { return existing }
        let fresh = LiveMonitorViewModel()
        runningViewModels[pairID] = fresh
        return fresh
    }

    func archiveRunningLog(for pairID: UUID) {
        guard let vm = runningViewModels[pairID] else { return }
        archivedViewModels[pairID] = vm
        runningViewModels[pairID] = nil
    }

    func hasArchivedLog(for pairID: UUID) -> Bool {
        archivedViewModels[pairID] != nil
    }

    func hasRunningLog(for pairID: UUID) -> Bool {
        runningViewModels[pairID] != nil
    }

    func present(pair: SyncPair, slot: LiveMonitorSlot, copy: AppCopy) {
        let available: Bool
        switch slot {
        case .running:  available = runningViewModels[pair.id] != nil
        case .archived: available = archivedViewModels[pair.id] != nil
        }
        guard available else { return }
        openedWindows[pair.id, default: []].insert(slot)
    }

    func close(pairID: UUID, slot: LiveMonitorSlot) {
        openedWindows[pairID]?.remove(slot)
        if openedWindows[pairID]?.isEmpty == true {
            openedWindows.removeValue(forKey: pairID)
        }
    }

    func viewModel(for pairID: UUID, slot: LiveMonitorSlot) -> LiveMonitorViewModel? {
        switch slot {
        case .running:  return runningViewModels[pairID]
        case .archived: return archivedViewModels[pairID]
        }
    }
}
