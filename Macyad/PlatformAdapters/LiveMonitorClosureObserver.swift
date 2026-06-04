import MacyadCore

/// Tiny adapter that lets the manual-run and scheduled-run wires feed a
/// `LiveMonitorViewModel` (or any `@MainActor`-isolated sink) via a single
/// `@Sendable @MainActor` closure. The struct itself is `Sendable` and
/// carries no non-Sendable state, so it can safely cross actor boundaries
/// to the `SyncService.runCommand` observer branch.
struct LiveMonitorClosureObserver: RcloneOutputObserver {
    let onLineCallback: @Sendable @MainActor (String) -> Void

    func onLine(_ line: String) async {
        await onLineCallback(line)
    }
}
