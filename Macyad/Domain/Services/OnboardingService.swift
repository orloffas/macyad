import Foundation

public protocol OnboardingServicing: Sendable {
    func refresh(pairCount: Int) async throws -> OnboardingState
}

public struct OnboardingService: OnboardingServicing {
    private static let suggestedRemoteName = "macyad-yandex"

    public let locator: RcloneLocating
    public let paths: AppPaths
    private let configURL: URL
    private let rcloneVersion: @Sendable (String) async -> String?

    public init(
        locator: RcloneLocating,
        paths: AppPaths,
        configURL: URL? = nil,
        rcloneVersion: (@Sendable (String) async -> String?)? = nil
    ) {
        self.locator = locator
        self.paths = paths
        self.configURL = configURL ?? paths.rcloneConfigFile
        self.rcloneVersion = rcloneVersion ?? Self.readRcloneVersion
    }

    public func refresh(pairCount: Int) async throws -> OnboardingState {
        let location = try await locator.locate()
        let version: String?
        let configuredRemoteName = RcloneConfigInspector(configURL: configURL).remoteNames().first
        let step: OnboardingState.Step

        if let location {
            version = await rcloneVersion(location)
        } else {
            version = nil
        }

        if location == nil {
            step = .installRclone
        } else if configuredRemoteName == nil {
            step = .configureRemote
        } else if pairCount > 0 {
            step = .complete
        } else {
            step = .createFirstPair
        }

        return OnboardingState(
            step: step,
            rcloneLocation: location,
            rcloneVersion: version,
            configuredRemoteName: configuredRemoteName,
            pairsCount: pairCount,
            brewInstallCommand: "brew install rclone",
            remoteCreateCommand: RcloneCommandBuilder.remoteCreateCommand(
                configPath: configURL.path,
                remoteName: Self.suggestedRemoteName
            ),
            configPath: configURL.path
        )
    }

    private static func readRcloneVersion(executablePath: String) async -> String? {
        guard let result = try? await RcloneProcessClient(executablePath: executablePath).run(["version"]),
              result.exitCode == 0 else {
            return nil
        }

        return result.stdout.split(whereSeparator: \.isNewline).first.map(String.init)
    }
}
