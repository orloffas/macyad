import Foundation

public protocol OnboardingServicing: Sendable {
    func refresh() async throws -> OnboardingState
}

public struct OnboardingService: OnboardingServicing {
    public let locator: RcloneLocating
    public let paths: AppPaths

    public init(locator: RcloneLocating, paths: AppPaths) {
        self.locator = locator
        self.paths = paths
    }

    public func refresh() async throws -> OnboardingState {
        let location = try await locator.locate()

        return OnboardingState(
            step: location == nil ? .installRclone : .configureRemote,
            rcloneLocation: location,
            brewInstallCommand: "brew install rclone",
            remoteCreateCommand: RcloneCommandBuilder.remoteCreateCommand(
                configPath: paths.appSupportRoot.appendingPathComponent("rclone.conf").path,
                remoteName: "yd-app"
            )
        )
    }
}
