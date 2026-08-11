import Combine
import Foundation

public protocol PasteboardWriting: AnyObject {
    func copy(_ string: String)
}

public struct OnboardingStatusRow: Equatable, Sendable {
    public let label: String
    public let value: String
    public let isSatisfied: Bool

    public init(label: String, value: String, isSatisfied: Bool) {
        self.label = label
        self.value = value
        self.isSatisfied = isSatisfied
    }
}

@MainActor
public final class OnboardingViewModel: ObservableObject {
    private let service: OnboardingServicing
    private let pasteboard: PasteboardWriting

    @Published public var state = OnboardingState(
        step: .installRclone,
        rcloneLocation: nil,
        rcloneVersion: nil,
        brewInstallCommand: "brew install rclone",
        remoteCreateCommand: "",
        configPath: ""
    )
    @Published public var isRefreshing = false
    @Published public var lastCopiedCommand: String?
    @Published public var lastCheckedAt: Date?

    public init(service: OnboardingServicing, pasteboard: PasteboardWriting) {
        self.service = service
        self.pasteboard = pasteboard
    }

    public func retry(pairCount: Int, now: Date = Date()) async {
        isRefreshing = true
        defer { isRefreshing = false }

        state = (try? await service.refresh(pairCount: pairCount)) ?? state
        lastCheckedAt = now
    }

    /// The step to render, adjusted for the pairs the app currently has.
    ///
    /// Creating or deleting a pair changes which step applies, but it says
    /// nothing about rclone or the remote — so the pane follows along without
    /// re-running the environment check, which spawns a process.
    public func displayStep(pairCount: Int) -> OnboardingState.Step {
        switch state.step {
        case .createFirstPair where pairCount > 0:
            return .complete
        case .complete where pairCount == 0:
            return .createFirstPair
        default:
            return state.step
        }
    }

    public func copy(_ command: String) {
        pasteboard.copy(command)
        lastCopiedCommand = command
    }

    public func statusRows(pairs: [SyncPair], preferences: AppPreferences, copy: AppCopy) -> [OnboardingStatusRow] {
        let schedulerStatus: String
        let hasScheduledPair = pairs.contains { $0.autoSyncMode != .off }

        if preferences.isGlobalSchedulerPaused {
            schedulerStatus = copy.onboardingSchedulerPaused
        } else if hasScheduledPair {
            schedulerStatus = copy.onboardingSchedulerActive
        } else {
            schedulerStatus = copy.onboardingSchedulerIdle
        }

        return [
            OnboardingStatusRow(
                label: copy.onboardingRcloneStatusLabel,
                value: state.rcloneLocation.map { location in
                    [state.rcloneVersion, location].compactMap { $0 }.joined(separator: " — ")
                } ?? copy.onboardingRcloneMissing,
                isSatisfied: state.rcloneLocation != nil
            ),
            OnboardingStatusRow(
                label: copy.onboardingRemoteStatusLabel,
                value: state.configuredRemoteName ?? copy.onboardingRemoteMissing,
                isSatisfied: state.configuredRemoteName != nil
            ),
            OnboardingStatusRow(
                label: copy.onboardingPairsStatusLabel,
                value: "\(pairs.count)",
                isSatisfied: !pairs.isEmpty
            ),
            OnboardingStatusRow(
                label: copy.onboardingSchedulerStatusLabel,
                value: schedulerStatus,
                // Every pair set to manual is a choice, not a fault; only the
                // global pause — which is easy to forget you switched on —
                // deserves the attention icon.
                isSatisfied: !preferences.isGlobalSchedulerPaused
            )
        ]
    }

    public func lastCheckedDescription(copy: AppCopy) -> String {
        copy.onboardingLastCheckedAt(lastCheckedAt.map(copy.formatTimestamp) ?? copy.onboardingNeverChecked)
    }
}
