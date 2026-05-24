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
        guard onboardingStep == .complete || !pairs.isEmpty else {
            return MenuBarSummary(title: "Setup required", alarmCount: 0, warningCount: 0)
        }

        let alarmCount = pairs.filter { $0.lastKnownSeverity == .alarm }.count
        let warningCount = pairs.filter { $0.lastKnownSeverity == .warning }.count
        let title = alarmCount > 0 ? "Attention required" : "Ready"

        return MenuBarSummary(title: title, alarmCount: alarmCount, warningCount: warningCount)
    }
}
