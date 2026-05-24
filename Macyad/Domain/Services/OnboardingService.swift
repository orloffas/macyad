import Foundation

public protocol OnboardingServicing: Sendable {
    func refresh() async throws -> OnboardingState
}

public struct OnboardingService: OnboardingServicing {
    private static let managedRemoteName = "yd"

    public let locator: RcloneLocating
    public let paths: AppPaths
    private let configURL: URL

    public init(locator: RcloneLocating, paths: AppPaths, configURL: URL? = nil) {
        self.locator = locator
        self.paths = paths
        self.configURL = configURL ?? Self.defaultConfigURL()
    }

    public func refresh() async throws -> OnboardingState {
        let location = try await locator.locate()
        let hasConfiguredRemote = configuredRemoteExists(at: configURL)
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
            remoteCreateCommand: RcloneCommandBuilder.remoteCreateCommand(remoteName: Self.managedRemoteName)
        )
    }

    private static func defaultConfigURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/rclone/rclone.conf", isDirectory: false)
    }

    private func configuredRemoteExists(at configPath: URL) -> Bool {
        guard let contents = try? String(contentsOf: configPath, encoding: .utf8) else {
            return false
        }

        return contents.contains("[\(Self.managedRemoteName)]")
    }
}
