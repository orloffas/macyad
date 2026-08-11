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
            paths: .makeForTesting(rootURL: URL(fileURLWithPath: "/tmp/MacyadTests", isDirectory: true)),
            rcloneVersion: { _ in "rclone v1.68.2" }
        )

        let state = try await service.refresh()

        XCTAssertEqual(state.step, .installRclone)
        XCTAssertEqual(state.brewInstallCommand, "brew install rclone")
        XCTAssertNil(state.rcloneVersion)
        XCTAssertEqual(state.configPath, "/tmp/MacyadTests/rclone/rclone.conf")
    }

    func testDetectedRcloneProducesRemoteSetupStep() async throws {
        let locator = StubRcloneLocator(location: "/opt/homebrew/bin/rclone")
        let configURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: false)
        let service = OnboardingService(
            locator: locator,
            paths: .makeForTesting(rootURL: URL(fileURLWithPath: "/tmp/MacyadTests", isDirectory: true)),
            configURL: configURL,
            rcloneVersion: { _ in "rclone v1.68.2" }
        )

        let state = try await service.refresh()

        XCTAssertEqual(state.step, .configureRemote)
        XCTAssertEqual(state.rcloneLocation, "/opt/homebrew/bin/rclone")
        XCTAssertEqual(state.rcloneVersion, "rclone v1.68.2")
        XCTAssertTrue(state.remoteCreateCommand.hasPrefix("rclone --config "))
        XCTAssertTrue(state.remoteCreateCommand.contains(" config create macyad-yandex yandex"))
        XCTAssertTrue(state.remoteCreateCommand.contains(configURL.path))
        XCTAssertEqual(state.configPath, configURL.path)
    }

    func testDetectedRcloneWithStandardConfiguredRemoteProducesCreateFirstPairStep() async throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let configURL = rootURL.appendingPathComponent(".config/rclone/rclone.conf")
        let paths = AppPaths.makeForTesting(rootURL: rootURL)
        let locator = StubRcloneLocator(location: "/opt/homebrew/bin/rclone")
        let service = OnboardingService(
            locator: locator,
            paths: paths,
            configURL: configURL,
            rcloneVersion: { _ in "rclone v1.68.2" }
        )

        defer {
            try? fileManager.removeItem(at: rootURL)
        }

        try fileManager.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        try """
        [yd]
        type = yandex
        """.write(
            to: configURL,
            atomically: true,
            encoding: .utf8
        )

        let state = try await service.refresh()

        XCTAssertEqual(state.step, .createFirstPair)
        XCTAssertEqual(state.rcloneLocation, "/opt/homebrew/bin/rclone")
        XCTAssertEqual(state.rcloneVersion, "rclone v1.68.2")
    }
}
