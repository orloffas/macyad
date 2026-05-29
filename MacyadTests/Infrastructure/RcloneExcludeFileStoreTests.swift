import Foundation
import XCTest
@testable import MacyadCore

final class RcloneExcludeFileStoreTests: XCTestCase {
    func testPrepareSyncExcludeFileWritesPatternsOnePerLine() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: rootURL) }

        let paths = AppPaths.makeForTesting(rootURL: rootURL)
        let store = PersistentRcloneExcludeFileStore(paths: paths, fileManager: fileManager)
        let pair = makePair(syncExcludes: [".DS_Store", ".git/**"], checkAdditionalExcludes: ["venv/**"])

        let filePath = try XCTUnwrap(store.prepareExcludeFile(for: pair, mode: .sync))
        let fileContents = try String(contentsOfFile: filePath, encoding: .utf8)

        XCTAssertEqual(URL(fileURLWithPath: filePath).deletingLastPathComponent(), paths.rcloneFiltersDirectory)
        XCTAssertEqual(fileContents, ".DS_Store\n.git/**\n")
    }

    func testPrepareCheckExcludeFileCombinesSyncAndAdditionalPatterns() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: rootURL) }

        let paths = AppPaths.makeForTesting(rootURL: rootURL)
        let store = PersistentRcloneExcludeFileStore(paths: paths, fileManager: fileManager)
        let pair = makePair(
            syncExcludes: [".DS_Store", ".venv/**"],
            checkAdditionalExcludes: [".git/**", ".pytest_cache/**"]
        )

        let filePath = try XCTUnwrap(store.prepareExcludeFile(for: pair, mode: .check))
        let fileContents = try String(contentsOfFile: filePath, encoding: .utf8)

        XCTAssertEqual(
            fileContents,
            ".DS_Store\n.venv/**\n.git/**\n.pytest_cache/**\n"
        )
    }

    func testPrepareSyncExcludeFileExpandsLiteralDirectoryPatternsRecursively() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: rootURL) }

        let paths = AppPaths.makeForTesting(rootURL: rootURL)
        let store = PersistentRcloneExcludeFileStore(paths: paths, fileManager: fileManager)
        let pair = makePair(
            syncExcludes: ["aacd64c1-18a5-4454-8baf-aa6f9127deaf", "Connections-OAS-Main (*).db"],
            checkAdditionalExcludes: []
        )

        let filePath = try XCTUnwrap(store.prepareExcludeFile(for: pair, mode: .sync))
        let fileContents = try String(contentsOfFile: filePath, encoding: .utf8)

        XCTAssertEqual(
            fileContents,
            """
            aacd64c1-18a5-4454-8baf-aa6f9127deaf
            aacd64c1-18a5-4454-8baf-aa6f9127deaf/**
            Connections-OAS-Main (*).db
            """
            + "\n"
        )
    }

    private func makePair(syncExcludes: [String], checkAdditionalExcludes: [String]) -> SyncPair {
        SyncPair(
            id: UUID(),
            name: "Docs",
            localFolderBookmark: Data("bookmark".utf8),
            localFolderDisplayPath: "/Users/test/Docs",
            remotePath: "yd:/Docs",
            scheduleMinutes: 15,
            deletePolicy: .mirrorToYandex,
            lastKnownSeverity: .healthy,
            syncExcludes: syncExcludes,
            checkAdditionalExcludes: checkAdditionalExcludes
        )
    }
}
