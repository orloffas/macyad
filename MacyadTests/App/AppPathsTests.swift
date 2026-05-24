import XCTest
@testable import MacyadCore

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

    func testLiveCreatesAppSupportAndWorkspaceDirectories() throws {
        let fileManager = FileManager.default
        let tempRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let appSupportDirectory = tempRoot.appendingPathComponent("Application Support", isDirectory: true)

        defer {
            try? fileManager.removeItem(at: tempRoot)
        }

        try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true, attributes: nil)

        let paths = try AppPaths.live(appSupportDirectory: appSupportDirectory, fileManager: fileManager)
        let expectedAppSupportRoot = appSupportDirectory.appendingPathComponent("Macyad", isDirectory: true)
        let expectedWorkspaceRoot = expectedAppSupportRoot.appendingPathComponent("Workspace", isDirectory: true)

        XCTAssertEqual(paths.appSupportRoot, expectedAppSupportRoot)
        XCTAssertEqual(paths.workspaceRoot, expectedWorkspaceRoot)
        XCTAssertTrue(fileManager.directoryExists(at: paths.appSupportRoot))
        XCTAssertTrue(fileManager.directoryExists(at: paths.workspaceRoot))
    }
}

private extension FileManager {
    func directoryExists(at url: URL) -> Bool {
        var isDirectory = ObjCBool(false)
        let exists = fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
}
