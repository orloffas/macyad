import XCTest
@testable import Macyad

final class AppPathsTests: XCTestCase {
    func testMakeForTestingBuildsCanonicalPaths() {
        let rootURL = URL(fileURLWithPath: "/tmp/MacyadTests", isDirectory: true)
        let paths = AppPaths.makeForTesting(rootURL: rootURL)

        XCTAssertEqual(paths.appSupportRoot, rootURL)
        XCTAssertEqual(paths.workspaceRoot, rootURL.appendingPathComponent("Workspace", isDirectory: true))
        XCTAssertEqual(paths.pairsFile, rootURL.appendingPathComponent("pairs.json"))
        XCTAssertEqual(paths.preferencesFile, rootURL.appendingPathComponent("preferences.json"))
        XCTAssertEqual(paths.activityFile, rootURL.appendingPathComponent("activity.json"))
    }
}
