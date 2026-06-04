import Foundation

/// Which captured log to look at for a pair.
public enum LiveMonitorSlot: Sendable, Hashable {
    /// The operation currently in flight (if any).
    case running
    /// The most recently completed operation's log (if any).
    case archived
}

@MainActor
public protocol LiveMonitorPresenting: AnyObject {
    /// Returns the running-slot view-model for the pair, creating one if
    /// none exists yet. Use at the start of an operation to attach the
    /// observer to a stable instance for the run's lifetime.
    func ensureRunningViewModel(for pairID: UUID) -> LiveMonitorViewModel
    /// Promote the running view-model to the archived slot (replacing any
    /// previous archive) and clear the running slot. Called when an op
    /// completes so the "Show last log" affordance can surface its output
    /// while the next op gets a fresh running slot.
    func archiveRunningLog(for pairID: UUID)
    /// Whether an archived log exists for this pair (any prior op).
    func hasArchivedLog(for pairID: UUID) -> Bool
    /// True if a running-slot view-model is currently registered.
    func hasRunningLog(for pairID: UUID) -> Bool
    /// Present the Live monitor window for the given slot. The window for
    /// running and the window for archived are independent — both can be
    /// open simultaneously. Brings an existing window for the same slot
    /// to the front. No-op if the slot is empty.
    func present(pair: SyncPair, slot: LiveMonitorSlot, copy: AppCopy)
    /// Close the window for the given slot (if open). Stored view-models
    /// are preserved so the window can be reopened.
    func close(pairID: UUID, slot: LiveMonitorSlot)
}
