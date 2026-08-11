import Combine
import Foundation

public protocol PasteboardWriting: AnyObject {
    func copy(_ string: String)
}

public struct OnboardingStatusRow: Equatable, Sendable {
    public let label: String
    public let value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
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

    public func retry(now: Date = Date()) async {
        isRefreshing = true
        defer { isRefreshing = false }

        state = (try? await service.refresh()) ?? state
        lastCheckedAt = now
    }

    public func copy(_ command: String) {
        pasteboard.copy(command)
        lastCopiedCommand = command
    }

    public func visibleStep(pairCount: Int) -> OnboardingState.Step {
        state.step == .createFirstPair && pairCount > 0 ? .complete : state.step
    }

    public func statusRows(pairs: [SyncPair], preferences: AppPreferences, copy: AppCopy) -> [OnboardingStatusRow] {
        let schedulerStatus: String

        if preferences.isGlobalSchedulerPaused {
            schedulerStatus = copy.onboardingSchedulerPaused
        } else if pairs.contains(where: { $0.autoSyncMode != .off }) {
            schedulerStatus = copy.onboardingSchedulerActive
        } else {
            schedulerStatus = copy.onboardingSchedulerIdle
        }

        return [
            OnboardingStatusRow(
                label: copy.onboardingRcloneStatusLabel,
                value: state.rcloneVersion ?? state.rcloneLocation ?? copy.onboardingRcloneMissing
            ),
            OnboardingStatusRow(
                label: copy.onboardingRemoteStatusLabel,
                value: state.step == .installRclone || state.step == .configureRemote
                    ? copy.onboardingRemoteMissing
                    : copy.onboardingRemoteConfigured
            ),
            OnboardingStatusRow(label: copy.onboardingPairsStatusLabel, value: "\(pairs.count)"),
            OnboardingStatusRow(label: copy.onboardingSchedulerStatusLabel, value: schedulerStatus),
            OnboardingStatusRow(
                label: copy.onboardingLastCheckStatusLabel,
                value: lastCheckedAt.map(copy.formatTimestamp) ?? copy.onboardingNeverChecked
            )
        ]
    }
}
