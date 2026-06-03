import Foundation

@MainActor
public protocol LiveMonitorPresenting: AnyObject {
    func present(pair: SyncPair, viewModel: LiveMonitorViewModel, copy: AppCopy, restartIfExisting: Bool)
    func close(pairID: UUID)
}
