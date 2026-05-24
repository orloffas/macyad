import XCTest
@testable import MacyadCore

final class OnboardingServiceTests: XCTestCase {
    private struct StubRcloneLocator: RcloneLocating {
        let location: String?

        func locate() async throws -> String? {
            location
        }
    }

    func testMissingRcloneProducesInstallStep() async throws {
        let locator = StubRcloneLocator(location: nil)
        let service = OnboardingService(
            locator: locator,
            paths: .makeForTesting(rootURL: URL(fileURLWithPath: "/tmp/MacyadTests", isDirectory: true))
        )

        let state = try await service.refresh()

        XCTAssertEqual(state.step, .installRclone)
        XCTAssertEqual(state.brewInstallCommand, "brew install rclone")
    }

    func testDetectedRcloneProducesRemoteSetupStep() async throws {
        let locator = StubRcloneLocator(location: "/opt/homebrew/bin/rclone")
        let service = OnboardingService(
            locator: locator,
            paths: .makeForTesting(rootURL: URL(fileURLWithPath: "/tmp/MacyadTests", isDirectory: true))
        )

        let state = try await service.refresh()

        XCTAssertEqual(state.step, .configureRemote)
        XCTAssertEqual(state.rcloneLocation, "/opt/homebrew/bin/rclone")
        XCTAssertTrue(state.remoteCreateCommand.contains("rclone config create"))
    }
}
