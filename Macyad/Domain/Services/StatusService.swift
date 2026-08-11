import Foundation

public struct MenuBarSummary: Equatable, Sendable {
    public var title: String
    public var alarmCount: Int
    public var warningCount: Int

    public init(title: String, alarmCount: Int, warningCount: Int) {
        self.title = title
        self.alarmCount = alarmCount
        self.warningCount = warningCount
    }
}

public struct StatusService: Sendable {
    public init() {}

    public func makeSummary(onboardingStep: OnboardingState.Step, pairs: [SyncPair]) -> MenuBarSummary {
        let copy = AppCopy.current

        // Pairs decide as much as the recorded step does. An import can replace
        // the configuration with zero pairs while the last environment check
        // still says `.complete`; the pane then asks for a first pair while the
        // menu bar claims everything is ready.
        guard !pairs.isEmpty else {
            return MenuBarSummary(title: copy.statusSetupRequired, alarmCount: 0, warningCount: 0)
        }

        let alarmCount = pairs.filter { $0.lastKnownSeverity == .alarm }.count
        let warningCount = pairs.filter { $0.lastKnownSeverity == .warning }.count
        let title: String

        if alarmCount > 0 {
            title = copy.statusAttentionRequired
        } else if warningCount > 0 {
            title = copy.statusWarningsPresent
        } else {
            title = copy.statusReady
        }

        return MenuBarSummary(title: title, alarmCount: alarmCount, warningCount: warningCount)
    }
}
