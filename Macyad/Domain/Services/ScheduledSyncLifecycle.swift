import Foundation

/// Hook invoked by `SchedulerService` around each scheduled sync so callers
/// can observe rclone output and react when the operation finishes. Used
/// today to feed the Live monitor's archived log for scheduled runs the
/// same way `MainWindowView.run(_:for:)` does for manual ones.
public struct ScheduledSyncLifecycle: Sendable {
    /// Called when the run is queued, before it reaches the front of the
    /// serial queue. Return a non-nil observer to receive every rclone log
    /// line; return nil to skip live observation for this run. The Live
    /// monitor is deliberately wired this early: a queued run is exactly when
    /// the user wants to see what the app is waiting for.
    public let willStart: @Sendable (SyncPair) async -> RcloneOutputObserver?
    /// Called when the run actually begins, i.e. once it has reached the front
    /// of the serial queue. Separate from `willStart` because the gap between
    /// the two can be long, and anything that tells the user "this is running"
    /// belongs here rather than there.
    public let didStart: @Sendable (SyncPair) async -> Void
    /// Called once the scheduled sync has produced its result (success,
    /// warning, or failure). Use this to finalize any live-monitor state
    /// (e.g. promote the running view-model into the archived slot).
    public let didFinish: @Sendable (SyncPair) async -> Void

    public init(
        willStart: @escaping @Sendable (SyncPair) async -> RcloneOutputObserver?,
        didStart: @escaping @Sendable (SyncPair) async -> Void = { _ in },
        didFinish: @escaping @Sendable (SyncPair) async -> Void
    ) {
        self.willStart = willStart
        self.didStart = didStart
        self.didFinish = didFinish
    }

    /// Default no-op lifecycle used when the caller does not wire a
    /// live-monitor (tests, headless environments).
    public static let noop = ScheduledSyncLifecycle(
        willStart: { _ in nil },
        didFinish: { _ in }
    )
}
