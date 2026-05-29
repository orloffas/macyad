import XCTest
@testable import MacyadCore

final class RcloneExcludeMatcherTests: XCTestCase {
    func testLiteralDirectoryPatternMatchesNestedFiles() {
        let matcher = RcloneExcludeMatcher(patterns: ["aacd64c1-18a5-4454-8baf-aa6f9127deaf"])

        XCTAssertTrue(
            matcher.matches(
                relativePath: "aacd64c1-18a5-4454-8baf-aa6f9127deaf/01-15-2026_11-51-25/Connections-OAS.rdm",
                isDirectory: false
            )
        )
    }

    func testLiteralDirectoryPatternDoesNotMatchUnrelatedSiblingPaths() {
        let matcher = RcloneExcludeMatcher(patterns: ["aacd64c1-18a5-4454-8baf-aa6f9127deaf"])

        XCTAssertFalse(
            matcher.matches(
                relativePath: "other-aacd64c1-18a5-4454-8baf-aa6f9127deaf/Connections-OAS.rdm",
                isDirectory: false
            )
        )
    }
}
