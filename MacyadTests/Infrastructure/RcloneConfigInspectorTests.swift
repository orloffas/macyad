import XCTest
@testable import MacyadCore

final class RcloneConfigInspectorTests: XCTestCase {
    func testRemoteNamesParsesSectionHeaders() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let configURL = root.appendingPathComponent("rclone.conf")

        defer {
            try? fileManager.removeItem(at: root)
        }

        try fileManager.createDirectory(at: root, withIntermediateDirectories: true, attributes: nil)
        try """
        [yd]
        type = yandex

        [team]
        type = yandex
        """.write(to: configURL, atomically: true, encoding: .utf8)

        let inspector = RcloneConfigInspector(configURL: configURL)
        XCTAssertEqual(inspector.remoteNames(), ["yd", "team"])
    }
}
