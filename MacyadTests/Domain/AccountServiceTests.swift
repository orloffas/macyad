import XCTest
@testable import MacyadCore

final class AccountServiceTests: XCTestCase {
    func testMakeAccountRejectsDuplicateRemoteNames() throws {
        let service = AccountService()
        let existing = [
            YandexAccount(
                id: UUID(),
                displayName: "Primary",
                remoteName: "yd-primary",
                configPath: "/tmp/rclone.conf",
                isManaged: true
            )
        ]

        XCTAssertThrowsError(
            try service.makeAccount(
                displayName: "Duplicate",
                remoteName: "yd-primary:",
                configPath: "/tmp/rclone.conf",
                existingAccounts: existing
            )
        ) { error in
            XCTAssertEqual(error as? AccountService.ValidationError, .duplicateRemoteName)
        }
    }

    func testReconcileAccountsImportsLegacyPairRemoteAndAssignsAccountID() {
        let service = AccountService()
        let legacyPair = SyncPair(
            id: UUID(),
            name: "Docs",
            localFolderBookmark: Data("bookmark".utf8),
            localFolderDisplayPath: "/Users/test/Docs",
            remotePath: "yd:/Docs",
            scheduleMinutes: 15,
            deletePolicy: .mirrorToYandex,
            lastKnownSeverity: .healthy
        )

        let result = service.reconcileAccounts(
            storedAccounts: [],
            pairs: [legacyPair],
            configPath: "/tmp/rclone.conf",
            configRemoteNames: ["yd"]
        )

        XCTAssertTrue(result.didMutate)
        XCTAssertEqual(result.accounts.map(\.remoteName), ["yd"])
        XCTAssertEqual(result.pairs.first?.parsedRemoteName, "yd")
        XCTAssertNotEqual(result.pairs.first?.accountID, SyncPair.unassignedAccountID)
    }

    func testSuggestedRemoteNameAddsPrefixAndAvoidsCollisions() {
        let service = AccountService()
        let existing = [
            YandexAccount(
                id: UUID(),
                displayName: "Main",
                remoteName: "macyad-personal",
                configPath: "/tmp/rclone.conf",
                isManaged: true
            )
        ]

        let suggestion = AccountService.suggestedRemoteName(for: "Personal", existingAccounts: existing)
        XCTAssertEqual(suggestion, "macyad-personal-2")
        _ = service
    }
}
