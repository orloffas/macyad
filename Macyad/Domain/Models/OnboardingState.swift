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
    public var brewInstallCommand: String
    public var remoteCreateCommand: String
    public var configPath: String

    public init(
        step: Step,
        rcloneLocation: String?,
        brewInstallCommand: String,
        remoteCreateCommand: String,
        configPath: String
    ) {
        self.step = step
        self.rcloneLocation = rcloneLocation
        self.brewInstallCommand = brewInstallCommand
        self.remoteCreateCommand = remoteCreateCommand
        self.configPath = configPath
    }
}
