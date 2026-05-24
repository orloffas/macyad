import XCTest
@testable import Macyad

final class AppPathsTests: XCTestCase {
    func testAppSupportRootEndsWithMacyad() {
        let paths = AppPaths.makeForTesting(rootURL: URL(fileURLWithPath: "/tmp/MacyadTests"))
        XCTAssertEqual(paths.appSupportRoot.lastPathComponent, "MacyadTests")
        XCTAssertEqual(paths.workspaceRoot.lastPathComponent, "Workspace")
        XCTAssertEqual(paths.pairsFile.lastPathComponent, "pairs.json")
    }
}
