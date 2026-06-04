import Foundation

@MainActor
public protocol LiveMonitorPresenting: AnyObject {
    /// Returns the existing in-memory view-model for the pair, or creates and
    /// stores a fresh one. The instance persists for the lifetime of the
    /// presenter so a closed window can be reopened without losing the log.
    func ensureViewModel(for pairID: UUID) -> LiveMonitorViewModel
    /// Returns the stored view-model for the pair, or nil if no operation
    /// has registered one yet in this session.
    func viewModel(for pairID: UUID) -> LiveMonitorViewModel?
    /// True if there is any captured log available for this pair (i.e. at
    /// least one operation has registered a view-model in this session).
    func hasLog(for pairID: UUID) -> Bool
    /// Show the Live monitor window for the given pair, using the stored
    /// view-model (created on demand). Brings an existing window to front.
    func present(pair: SyncPair, copy: AppCopy)
    /// Close the Live monitor window for the pair if open. The stored
    /// view-model is preserved so the window can be reopened later.
    func close(pairID: UUID)
}
