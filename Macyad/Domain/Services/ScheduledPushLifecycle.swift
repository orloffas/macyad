import Foundation

/// Hook invoked by `SchedulerService` around each scheduled push so callers
/// can observe rclone output and react when the operation finishes. Used
/// today to feed the Live monitor's archived log for scheduled runs the
/// same way `MainWindowView.run(_:for:)` does for manual ones.
public struct ScheduledPushLifecycle: Sendable {
    /// Called immediately before `SyncService.push(...)` is invoked for a
    /// scheduled run. Return a non-nil observer to receive every rclone log
    /// line; return nil to skip live observation for this run.
    public let willStart: @Sendable (SyncPair) async -> RcloneOutputObserver?
    /// Called once the scheduled push has produced its result (success,
    /// warning, or failure). Use this to finalize any live-monitor state
    /// (e.g. promote the running view-model into the archived slot).
    public let didFinish: @Sendable (SyncPair) async -> Void

    public init(
        willStart: @escaping @Sendable (SyncPair) async -> RcloneOutputObserver?,
        didFinish: @escaping @Sendable (SyncPair) async -> Void
    ) {
        self.willStart = willStart
        self.didFinish = didFinish
    }

    /// Default no-op lifecycle used when the caller does not wire a
    /// live-monitor (tests, headless environments).
    public static let noop = ScheduledPushLifecycle(
        willStart: { _ in nil },
        didFinish: { _ in }
    )
}
