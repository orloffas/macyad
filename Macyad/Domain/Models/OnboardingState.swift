import Foundation

public struct OnboardingState: Equatable, Sendable {
    public enum Step: Equatable, Sendable {
        case installRclone
        case configureRemote
        case createFirstPair
        case complete
    }

    public var step: Step
    public var rcloneLocation: String?
    public var rcloneVersion: String?
    public var configuredRemoteName: String?
    public var pairsCount: Int
    public var brewInstallCommand: String
    public var remoteCreateCommand: String
    public var configPath: String

    public init(
        step: Step,
        rcloneLocation: String?,
        rcloneVersion: String? = nil,
        configuredRemoteName: String? = nil,
        pairsCount: Int = 0,
        brewInstallCommand: String,
        remoteCreateCommand: String,
        configPath: String
    ) {
        self.step = step
        self.rcloneLocation = rcloneLocation
        self.rcloneVersion = rcloneVersion
        self.configuredRemoteName = configuredRemoteName
        self.pairsCount = pairsCount
        self.brewInstallCommand = brewInstallCommand
        self.remoteCreateCommand = remoteCreateCommand
        self.configPath = configPath
    }
}
