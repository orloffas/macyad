import XCTest
@testable import MacyadCore

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    private struct StubOnboardingService: OnboardingServicing {
        let step: OnboardingState.Step

        func refresh() async throws -> OnboardingState {
            OnboardingState(
                step: step,
                rcloneLocation: step == .installRclone ? nil : "/opt/homebrew/bin/rclone",
                brewInstallCommand: "brew install rclone",
                remoteCreateCommand: "rclone config create yd-app yandex --config /tmp/rclone.conf",
                configPath: "/tmp/rclone.conf"
            )
        }
    }

    private final class StubPasteboard: PasteboardWriting {
        private(set) var copiedStrings: [String] = []

        func copy(_ string: String) {
            copiedStrings.append(string)
        }
    }

    func testRetryRefreshesState() async throws {
        let service = StubOnboardingService(step: .configureRemote)
        let pasteboard = StubPasteboard()
        let model = OnboardingViewModel(service: service, pasteboard: pasteboard)

        await model.retry()

        XCTAssertEqual(model.state.step, .configureRemote)
        XCTAssertEqual(model.state.rcloneLocation, "/opt/homebrew/bin/rclone")
        XCTAssertFalse(model.isRefreshing)
    }

    func testCopyMarksCommandAsCopied() async throws {
        let pasteboard = StubPasteboard()
        let model = OnboardingViewModel(
            service: StubOnboardingService(step: .installRclone),
            pasteboard: pasteboard
        )

        model.copy("brew install rclone")

        XCTAssertEqual(model.lastCopiedCommand, "brew install rclone")
        XCTAssertEqual(pasteboard.copiedStrings, ["brew install rclone"])
    }
}
