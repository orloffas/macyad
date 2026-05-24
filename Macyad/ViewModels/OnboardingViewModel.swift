import Combine

public protocol PasteboardWriting: AnyObject {
    func copy(_ string: String)
}

@MainActor
public final class OnboardingViewModel: ObservableObject {
    private let service: OnboardingServicing
    private let pasteboard: PasteboardWriting

    @Published public var state = OnboardingState(
        step: .installRclone,
        rcloneLocation: nil,
        brewInstallCommand: "brew install rclone",
        remoteCreateCommand: ""
    )
    @Published public var isRefreshing = false
    @Published public var lastCopiedCommand: String?

    public init(service: OnboardingServicing, pasteboard: PasteboardWriting) {
        self.service = service
        self.pasteboard = pasteboard
    }

    public func retry() async {
        isRefreshing = true
        defer { isRefreshing = false }

        state = (try? await service.refresh()) ?? state
    }

    public func copy(_ command: String) {
        pasteboard.copy(command)
        lastCopiedCommand = command
    }
}
