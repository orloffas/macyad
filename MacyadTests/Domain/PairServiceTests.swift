import XCTest
@testable import MacyadCore

final class PairServiceTests: XCTestCase {
    private let accountID = UUID()

    func testCreateRejectsEmptyRemotePath() throws {
        let service = PairService()

        XCTAssertThrowsError(
            try service.makePair(
                name: "Work Docs",
                localFolderBookmark: Data("bookmark".utf8),
                localFolderDisplayPath: "/Users/test/Work Docs",
                remotePath: "",
                accountID: accountID,
                conflictPolicy: .block,
                scheduleMinutes: 30,
                deletePolicy: .mirrorToYandex
            )
        ) { error in
            XCTAssertEqual(error as? PairService.ValidationError, .emptyRemotePath)
        }
    }

    func testCreateRejectsMissingLocalFolder() throws {
        let service = PairService()

        XCTAssertThrowsError(
            try service.makePair(
                name: "Work Docs",
                localFolderBookmark: Data(),
                localFolderDisplayPath: "",
                remotePath: "yd:/Work Docs",
                accountID: accountID,
                conflictPolicy: .block,
                scheduleMinutes: 30,
                deletePolicy: .mirrorToYandex
            )
        ) { error in
            XCTAssertEqual(error as? PairService.ValidationError, .missingLocalFolder)
        }
    }

    func testValidationErrorMessagesFollowSelectedLanguage() {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        XCTAssertEqual(PairService.ValidationError.emptyName.localizedDescription, "Enter a pair name.")

        AppLanguageState.update(.russian)

        XCTAssertEqual(PairService.ValidationError.emptyName.localizedDescription, "Введите имя пары.")
    }

    func testCreateUsesDefaultSyncExcludesAndEmptyAdditionalCheckExcludes() throws {
        let service = PairService()

        let pair = try service.makePair(
            name: "Work Docs",
            localFolderBookmark: Data("bookmark".utf8),
            localFolderDisplayPath: "/Users/test/Work Docs",
            remotePath: "yd:/Work Docs",
            accountID: accountID,
            conflictPolicy: .block,
            scheduleMinutes: 30,
            deletePolicy: .mirrorToYandex
        )

        XCTAssertEqual(pair.syncExcludes, SyncPair.defaultSyncExcludes)
        XCTAssertEqual(pair.checkAdditionalExcludes, [String]())
    }

    func testUpdatePreservesIdentityAndOperationalFields() throws {
        let service = PairService()
        let existingPair = SyncPair(
            id: UUID(),
            name: "Old",
            localFolderBookmark: Data("bookmark".utf8),
            localFolderDisplayPath: "/Users/test/Old",
            remotePath: "yd:/old",
            accountID: accountID,
            conflictPolicy: .block,
            scheduleMinutes: 20,
            deletePolicy: .mirrorToYandex,
            lastKnownSeverity: .alarm,
            lastSyncAt: Date(timeIntervalSince1970: 456),
            lastScheduledPushAttemptAt: Date(timeIntervalSince1970: 789)
        )

        let updatedPair = try service.updatePair(
            existingPair,
            name: "New",
            localFolderBookmark: Data("new-bookmark".utf8),
            localFolderDisplayPath: "/Users/test/New",
            remotePath: "yd:/new",
            accountID: accountID,
            conflictPolicy: .keepBoth,
            scheduleMinutes: 45,
            deletePolicy: .keepRemoteDeletesManual,
            syncExcludes: ["Thumbs.db"],
            checkAdditionalExcludes: ["Desktop.ini"]
        )

        XCTAssertEqual(updatedPair.id, existingPair.id)
        XCTAssertEqual(updatedPair.lastKnownSeverity, Severity.alarm)
        XCTAssertEqual(updatedPair.lastSyncAt, existingPair.lastSyncAt)
        XCTAssertEqual(updatedPair.lastScheduledPushAttemptAt, existingPair.lastScheduledPushAttemptAt)
        XCTAssertEqual(updatedPair.name, "New")
        XCTAssertEqual(updatedPair.accountID, accountID)
        XCTAssertEqual(updatedPair.conflictPolicy, .keepBoth)
        XCTAssertEqual(updatedPair.syncExcludes, ["Thumbs.db"])
        XCTAssertEqual(updatedPair.checkAdditionalExcludes, ["Desktop.ini"])
    }

    func testRemoveRejectsDeletingLastPair() throws {
        let service = PairService()
        let pair = SyncPair(
            id: UUID(),
            name: "Only Pair",
            localFolderBookmark: Data("bookmark".utf8),
            localFolderDisplayPath: "/Users/test/Only",
            remotePath: "yd:/only",
            accountID: accountID,
            conflictPolicy: .block,
            scheduleMinutes: 15,
            deletePolicy: .mirrorToYandex,
            lastKnownSeverity: .healthy
        )

        XCTAssertThrowsError(try service.removePair(pair, from: [pair])) { error in
            XCTAssertEqual(error as? PairService.ValidationError, .lastPairDeletion)
        }
    }
}
