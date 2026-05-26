import Foundation
import XCTest
@testable import MacyadCore

final class SyncPairTests: XCTestCase {
    func testLegacyDecodeAppliesDefaultExcludeLists() throws {
        let json = """
        {
          "id": "8A6DFB16-5E36-49E5-A406-0549A5135363",
          "name": "Docs",
          "localFolderBookmark": "Ym9va21hcms=",
          "localFolderDisplayPath": "/Users/test/Docs",
          "remotePath": "yd:/Docs",
          "scheduleMinutes": 30,
          "deletePolicy": "mirrorToYandex",
          "lastKnownSeverity": "healthy",
          "lastSyncAt": null
        }
        """

        let pair = try JSONDecoder().decode(SyncPair.self, from: Data(json.utf8))

        XCTAssertEqual(pair.syncExcludes, SyncPair.defaultSyncExcludes)
        XCTAssertTrue(pair.syncExcludes.contains("Icon?"))
        XCTAssertEqual(pair.checkAdditionalExcludes, [String]())
        XCTAssertNil(pair.lastScheduledPushAttemptAt)
        XCTAssertEqual(pair.accountID, SyncPair.unassignedAccountID)
        XCTAssertEqual(pair.conflictPolicy, .block)
    }

    func testDecodePreservesExplicitExcludeLists() throws {
        let json = """
        {
          "id": "8A6DFB16-5E36-49E5-A406-0549A5135363",
          "name": "Docs",
          "localFolderBookmark": "Ym9va21hcms=",
          "localFolderDisplayPath": "/Users/test/Docs",
          "remotePath": "yd:/Docs",
          "scheduleMinutes": 30,
          "deletePolicy": "mirrorToYandex",
          "lastKnownSeverity": "healthy",
          "lastSyncAt": null,
          "lastScheduledPushAttemptAt": 1234,
          "syncExcludes": [".DS_Store"],
          "checkAdditionalExcludes": ["Thumbs.db"]
        }
        """

        let pair = try JSONDecoder().decode(SyncPair.self, from: Data(json.utf8))

        XCTAssertEqual(pair.syncExcludes, [".DS_Store"])
        XCTAssertEqual(pair.checkAdditionalExcludes, ["Thumbs.db"])
        XCTAssertEqual(pair.lastScheduledPushAttemptAt, Date(timeIntervalSinceReferenceDate: 1234))
    }

    func testRemotePathHelpersSplitAndComposeFullPath() {
        XCTAssertEqual(SyncPair.remoteName(from: "yd:/Docs/Work"), "yd")
        XCTAssertEqual(SyncPair.remoteSubpath(from: "yd:/Docs/Work"), "Docs/Work")
        XCTAssertEqual(SyncPair.composeRemotePath(remoteName: "yd", remoteSubpath: "Docs/Work"), "yd:/Docs/Work")
    }
}
