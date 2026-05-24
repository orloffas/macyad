import Foundation

protocol OnboardingServicing: Sendable {
    func refresh() async throws -> OnboardingState
}

struct OnboardingService: OnboardingServicing {
    let locator: RcloneLocating
    let paths: AppPaths

    func refresh() async throws -> OnboardingState {
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
