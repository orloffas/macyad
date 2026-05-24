import Foundation

public protocol OnboardingServicing: Sendable {
    func refresh() async throws -> OnboardingState
}

public struct OnboardingService: OnboardingServicing {
    private static let managedRemoteName = "yd-app"

    public let locator: RcloneLocating
    public let paths: AppPaths

    public init(locator: RcloneLocating, paths: AppPaths) {
        self.locator = locator
        self.paths = paths
    }

    public func refresh() async throws -> OnboardingState {
        let location = try await locator.locate()
        let configPath = paths.appSupportRoot.appendingPathComponent("rclone.conf")
        let hasConfiguredRemote = configuredRemoteExists(at: configPath)
        let step: OnboardingState.Step

        if location == nil {
            step = .installRclone
        } else if hasConfiguredRemote {
            step = .createFirstPair
        } else {
            step = .configureRemote
        }

        return OnboardingState(
            step: step,
            rcloneLocation: location,
            brewInstallCommand: "brew install rclone",
            remoteCreateCommand: RcloneCommandBuilder.remoteCreateCommand(
                configPath: configPath.path,
                remoteName: Self.managedRemoteName
            )
        )
    }

    private func configuredRemoteExists(at configPath: URL) -> Bool {
        guard let contents = try? String(contentsOf: configPath, encoding: .utf8) else {
            return false
        }

        return contents.contains("[\(Self.managedRemoteName)]")
    }
}
