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

    func testRemovalStateAllowsUnusedAccount() {
        let service = AccountService()
        let account = YandexAccount(
            id: UUID(),
            displayName: "Primary",
            remoteName: "yd-primary",
            configPath: "/tmp/rclone.conf",
            isManaged: true
        )

        let state = service.removalState(for: account, pairs: [], copy: AppCopy(language: .english))

        XCTAssertTrue(state.canRemove)
        XCTAssertEqual(state.blockingPairNames, [])
        XCTAssertNil(state.inlineMessage)
    }

    func testRemovalStateIncludesSingleBlockingPairName() {
        let service = AccountService()
        let account = YandexAccount(
            id: UUID(),
            displayName: "Primary",
            remoteName: "yd-primary",
            configPath: "/tmp/rclone.conf",
            isManaged: true
        )
        let pair = SyncPair(
            id: UUID(),
            name: "Docs",
            localFolderBookmark: Data("bookmark".utf8),
            localFolderDisplayPath: "/Users/test/Docs",
            remotePath: "yd-primary:/docs",
            accountID: account.id,
            conflictPolicy: .block,
            scheduleMinutes: 15,
            deletePolicy: .mirrorToYandex,
            lastKnownSeverity: .healthy
        )

        let state = service.removalState(for: account, pairs: [pair], copy: AppCopy(language: .english))

        XCTAssertFalse(state.canRemove)
        XCTAssertEqual(state.blockingPairNames, ["Docs"])
        XCTAssertEqual(state.inlineMessage, "This account can't be removed while pair Docs still references it.")
    }

    func testRemovalStateIncludesAllBlockingPairNames() {
        let service = AccountService()
        let account = YandexAccount(
            id: UUID(),
            displayName: "Primary",
            remoteName: "yd-primary",
            configPath: "/tmp/rclone.conf",
            isManaged: true
        )
        let docs = SyncPair(
            id: UUID(),
            name: "Docs",
            localFolderBookmark: Data("bookmark".utf8),
            localFolderDisplayPath: "/Users/test/Docs",
            remotePath: "yd-primary:/docs",
            accountID: account.id,
            conflictPolicy: .block,
            scheduleMinutes: 15,
            deletePolicy: .mirrorToYandex,
            lastKnownSeverity: .healthy
        )
        let photos = SyncPair(
            id: UUID(),
            name: "Photos",
            localFolderBookmark: Data("bookmark".utf8),
            localFolderDisplayPath: "/Users/test/Photos",
            remotePath: "yd-primary:/photos",
            accountID: account.id,
            conflictPolicy: .block,
            scheduleMinutes: 15,
            deletePolicy: .mirrorToYandex,
            lastKnownSeverity: .healthy
        )

        let state = service.removalState(for: account, pairs: [photos, docs], copy: AppCopy(language: .russian))

        XCTAssertFalse(state.canRemove)
        XCTAssertEqual(state.blockingPairNames, ["Docs", "Photos"])
        XCTAssertEqual(state.inlineMessage, "Account нельзя удалить, пока к нему привязаны pair: Docs, Photos.")
    }
}
