import XCTest
@testable import MacyadCore

final class RcloneLocatorTests: XCTestCase {
    func testLocateReturnsFirstMatchingCandidate() async throws {
        let locator = RcloneLocator(
            candidates: [
                "/opt/homebrew/bin/rclone",
                "/usr/local/bin/rclone"
            ],
            fileExists: { path in
                path == "/usr/local/bin/rclone"
            }
        )

        let location = try await locator.locate()

        XCTAssertEqual(location, "/usr/local/bin/rclone")
    }

    func testLocateReturnsNilWhenCandidatesAreMissing() async throws {
        let locator = RcloneLocator(
            candidates: ["/opt/homebrew/bin/rclone"],
            fileExists: { _ in false }
        )

        let location = try await locator.locate()

        XCTAssertNil(location)
    }
}
