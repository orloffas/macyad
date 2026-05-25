import Foundation
import XCTest
@testable import MacyadCore

final class LocalFolderInspectorTests: XCTestCase {
    func testHiddenOnlyTopLevelItemsDoNotCountAsUserVisibleContent() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: rootURL) }

        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true, attributes: nil)
        try Data().write(to: rootURL.appendingPathComponent(".gitkeep"))
        try Data().write(to: rootURL.appendingPathComponent(".DS_Store"))
        try Data().write(to: rootURL.appendingPathComponent("._draft"))

        let inspector = FileManagerLocalFolderInspector()

        XCTAssertFalse(try inspector.containsUserVisibleContent(atPath: rootURL.path))
    }

    func testVisibleTopLevelItemsCountAsUserVisibleContent() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: rootURL) }

        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true, attributes: nil)
        try Data("hello".utf8).write(to: rootURL.appendingPathComponent("notes.txt"))

        let inspector = FileManagerLocalFolderInspector()

        XCTAssertTrue(try inspector.containsUserVisibleContent(atPath: rootURL.path))
    }
}
