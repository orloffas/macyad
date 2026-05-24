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

    func testDetectedRcloneWithConfiguredRemoteProducesCreateFirstPairStep() async throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let paths = AppPaths.makeForTesting(rootURL: rootURL)
        let locator = StubRcloneLocator(location: "/opt/homebrew/bin/rclone")
        let service = OnboardingService(locator: locator, paths: paths)

        defer {
            try? fileManager.removeItem(at: rootURL)
        }

        try fileManager.createDirectory(at: paths.appSupportRoot, withIntermediateDirectories: true, attributes: nil)
        try """
        [yd-app]
        type = yandex
        """.write(
            to: paths.appSupportRoot.appendingPathComponent("rclone.conf"),
            atomically: true,
            encoding: .utf8
        )

        let state = try await service.refresh()

        XCTAssertEqual(state.step, .createFirstPair)
        XCTAssertEqual(state.rcloneLocation, "/opt/homebrew/bin/rclone")
    }
}
