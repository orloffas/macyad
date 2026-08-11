import Foundation

/// Direction the background scheduler is allowed to run for a pair.
///
/// Modelled as a single enum rather than two independent `Bool` flags on
/// purpose: push and pull are mutually exclusive by product decision, and a
/// pair of booleans would make the invalid "both enabled" state representable.
/// Running both directions in one cycle would require a per-path selective
/// engine (pull only remote-only paths, push only local-only paths); the
/// all-or-nothing `rclone sync` / `rclone copy` operations used here cannot do
/// it safely.
public enum AutoSyncMode: String, Codable, CaseIterable, Sendable {
    case off
    case push
    case pull
}
