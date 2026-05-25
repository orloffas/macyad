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

    func testExcludedVisibleTopLevelItemsDoNotCountAsUserVisibleContent() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: rootURL) }

        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true, attributes: nil)
        try Data().write(to: rootURL.appendingPathComponent("Thumbs.db"))
        try Data().write(to: rootURL.appendingPathComponent("desktop.ini"))

        let inspector = FileManagerLocalFolderInspector()

        XCTAssertFalse(
            try inspector.containsUserVisibleContent(
                atPath: rootURL.path,
                excludedPatterns: ["Thumbs.db", "desktop.ini"]
            )
        )
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

    func testVisibleNestedItemsInsideExcludedDirectoriesDoNotCountAsUserVisibleContent() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let cacheURL = rootURL.appendingPathComponent("System Volume Information", isDirectory: true)
        defer { try? fileManager.removeItem(at: rootURL) }

        try fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true, attributes: nil)
        try Data("index".utf8).write(to: cacheURL.appendingPathComponent("store.db"))

        let inspector = FileManagerLocalFolderInspector()

        XCTAssertFalse(
            try inspector.containsUserVisibleContent(
                atPath: rootURL.path,
                excludedPatterns: ["System Volume Information/**"]
            )
        )
    }
}
