import Foundation

struct OnboardingState: Equatable, Sendable {
    enum Step: Equatable, Sendable {
        case installRclone
        case configureRemote
        case createFirstPair
        case complete
    }

    var step: Step
    var rcloneLocation: String?
    var brewInstallCommand: String
    var remoteCreateCommand: String
}
