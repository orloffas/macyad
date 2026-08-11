import XCTest
@testable import MacyadCore

final class ConfigurationTransferServiceTests: XCTestCase {
    private let service = ConfigurationTransferService()
    private let accountID = UUID()

    func testExportDropsBookmarksAndRunHistory() {
        let pair = makePair(
            bookmark: Data([1, 2, 3]),
            lastSyncAt: Date(timeIntervalSince1970: 1_716_580_800),
            severity: .alarm
        )

        let export = service.makeExport(
            preferences: .defaults,
            accounts: [makeAccount()],
            pairs: [pair],
            at: Date(timeIntervalSince1970: 1_716_584_400)
        )

        // A bookmark is tied to this Mac and its TCC grants, and the run
        // history describes runs that happened here, not on the machine that
        // will read this file.
        XCTAssertEqual(export.pairs.count, 1)
        XCTAssertTrue(export.pairs[0].localFolderBookmark.isEmpty)
        XCTAssertNil(export.pairs[0].lastSyncAt)
        XCTAssertNil(export.pairs[0].lastScheduledSyncAttemptAt)
        XCTAssertEqual(export.pairs[0].lastKnownSeverity, .healthy)
        XCTAssertEqual(export.pairs[0].name, pair.name)
        XCTAssertEqual(export.pairs[0].remotePath, pair.remotePath)
        XCTAssertEqual(export.schemaVersion, ConfigurationExport.currentSchemaVersion)
    }

    func testExportRoundTripsThroughJSON() throws {
        let export = service.makeExport(
            preferences: .defaults,
            accounts: [makeAccount()],
            pairs: [makePair()],
            at: Date(timeIntervalSince1970: 1_716_584_400)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        XCTAssertEqual(try decoder.decode(ConfigurationExport.self, from: encoder.encode(export)), export)
    }

    func testImportTurnsSchedulingOffAndRewritesConfigPath() throws {
        var pair = makePair()
        pair.autoSyncMode = .push
        var account = makeAccount()
        account.configPath = "/Users/someone-else/.config/rclone/rclone.conf"
        let export = ConfigurationExport(
            exportedAt: Date(timeIntervalSince1970: 1_716_584_400),
            preferences: AppPreferences(
                selectedLanguage: "ru",
                launchAtLoginEnabled: true,
                defaultScheduleMinutes: 30,
                isGlobalSchedulerPaused: false
            ),
            accounts: [account],
            pairs: [pair]
        )

        let plan = try service.prepareImport(
            export,
            configPath: "/Users/me/.config/rclone/rclone.conf",
            availableRemoteNames: ["macyad-yandex"],
            folderExists: { _ in true },
            bookmarkForPath: { _ in Data([9, 9]) }
        )

        // Scheduling stays off until the user has checked the two sides: a
        // scheduled mirroring push against a folder this Mac has not verified
        // could clear the remote.
        XCTAssertEqual(plan.pairs[0].autoSyncMode, .off)
        XCTAssertTrue(plan.preferences.isGlobalSchedulerPaused)
        XCTAssertNil(plan.pairs[0].lastSyncAt)
        XCTAssertEqual(plan.pairs[0].localFolderBookmark, Data([9, 9]))
        XCTAssertEqual(plan.accounts[0].configPath, "/Users/me/.config/rclone/rclone.conf")
        XCTAssertEqual(plan.preferences.defaultScheduleMinutes, 30)
        XCTAssertTrue(plan.issues.isEmpty)
    }

    func testImportReportsMissingFolderButKeepsThePair() throws {
        let export = ConfigurationExport(
            exportedAt: Date(timeIntervalSince1970: 1_716_584_400),
            preferences: .defaults,
            accounts: [makeAccount()],
            pairs: [makePair(name: "Docs")]
        )

        let plan = try service.prepareImport(
            export,
            configPath: "/Users/me/.config/rclone/rclone.conf",
            availableRemoteNames: ["macyad-yandex"],
            folderExists: { _ in false },
            bookmarkForPath: { _ in XCTFail("no bookmark for a folder that is not there"); return nil }
        )

        XCTAssertEqual(plan.pairs.count, 1)
        XCTAssertTrue(plan.pairs[0].localFolderBookmark.isEmpty)
        XCTAssertEqual(
            plan.issues,
            [ConfigurationImportIssue(pairName: "Docs", kind: .unusableLocalFolder(path: "/Users/me/Documents/Docs"))]
        )
    }

    func testImportReportsMissingRemote() throws {
        let export = ConfigurationExport(
            exportedAt: Date(timeIntervalSince1970: 1_716_584_400),
            preferences: .defaults,
            accounts: [makeAccount()],
            pairs: [makePair(name: "Docs")]
        )

        let plan = try service.prepareImport(
            export,
            configPath: "/Users/me/.config/rclone/rclone.conf",
            availableRemoteNames: ["some-other-remote"],
            folderExists: { _ in true },
            bookmarkForPath: { _ in Data([1]) }
        )

        XCTAssertEqual(
            plan.issues,
            [ConfigurationImportIssue(pairName: "Docs", kind: .missingRemote(name: "macyad-yandex"))]
        )
    }

    func testImportDropsDuplicateIDs() throws {
        let pairID = UUID()
        let account = makeAccount()
        let export = ConfigurationExport(
            exportedAt: Date(timeIntervalSince1970: 1_716_584_400),
            preferences: .defaults,
            accounts: [account, account],
            pairs: [makePair(id: pairID, name: "Docs"), makePair(id: pairID, name: "Docs copy")]
        )

        let plan = try service.prepareImport(
            export,
            configPath: "/Users/me/.config/rclone/rclone.conf",
            availableRemoteNames: ["macyad-yandex"],
            folderExists: { _ in true },
            bookmarkForPath: { _ in Data([1]) }
        )

        // Two pairs under one id break SwiftUI's Identifiable lists, so a
        // hand-edited file cannot smuggle them in.
        XCTAssertEqual(plan.pairs.count, 1)
        XCTAssertEqual(plan.pairs[0].name, "Docs")
        XCTAssertEqual(plan.accounts.count, 1)
    }

    func testImportReportsPairWithoutItsAccount() throws {
        let export = ConfigurationExport(
            exportedAt: Date(timeIntervalSince1970: 1_716_584_400),
            preferences: .defaults,
            accounts: [makeAccount()],
            pairs: [makePair(name: "Orphan", accountID: UUID())]
        )

        let plan = try service.prepareImport(
            export,
            configPath: "/Users/me/.config/rclone/rclone.conf",
            availableRemoteNames: ["macyad-yandex"],
            folderExists: { _ in true },
            bookmarkForPath: { _ in Data([1]) }
        )

        XCTAssertEqual(plan.pairs.count, 1)
        XCTAssertEqual(plan.issues, [ConfigurationImportIssue(pairName: "Orphan", kind: .missingAccount)])
    }

    func testDecodeRejectsNewerSchemaBeforeReadingTheRest() throws {
        // The pairs are deliberately nonsense: a newer file may describe them
        // in a shape this build cannot decode, and the version has to win.
        let json = """
        {
          "schemaVersion": \(ConfigurationExport.currentSchemaVersion + 1),
          "exportedAt": "2026-08-11T09:00:00Z",
          "preferences": "not-what-this-build-expects",
          "accounts": 42,
          "pairs": null
        }
        """

        XCTAssertThrowsError(try service.decodeExport(from: Data(json.utf8))) { error in
            XCTAssertEqual(
                error as? ConfigurationTransferService.ImportError,
                .unsupportedSchema(
                    found: ConfigurationExport.currentSchemaVersion + 1,
                    supported: ConfigurationExport.currentSchemaVersion
                )
            )
        }
    }

    func testImportRejectsNewerSchema() {
        var export = ConfigurationExport(
            exportedAt: Date(timeIntervalSince1970: 1_716_584_400),
            preferences: .defaults,
            accounts: [],
            pairs: []
        )
        export.schemaVersion = ConfigurationExport.currentSchemaVersion + 1

        XCTAssertThrowsError(
            try service.prepareImport(
                export,
                configPath: "/Users/me/.config/rclone/rclone.conf",
                availableRemoteNames: [],
                folderExists: { _ in true },
                bookmarkForPath: { _ in nil }
            )
        ) { error in
            XCTAssertEqual(
                error as? ConfigurationTransferService.ImportError,
                .unsupportedSchema(
                    found: ConfigurationExport.currentSchemaVersion + 1,
                    supported: ConfigurationExport.currentSchemaVersion
                )
            )
        }
    }

    private func makeAccount() -> YandexAccount {
        YandexAccount(
            id: accountID,
            displayName: "macyad-yandex",
            remoteName: "macyad-yandex",
            configPath: "/Users/me/.config/rclone/rclone.conf",
            isManaged: false,
            createdAt: Date(timeIntervalSince1970: 1_716_000_000)
        )
    }

    private func makePair(
        id: UUID = UUID(),
        name: String = "Docs",
        bookmark: Data = Data(),
        lastSyncAt: Date? = nil,
        severity: Severity = .healthy,
        accountID: UUID? = nil
    ) -> SyncPair {
        SyncPair(
            id: id,
            name: name,
            localFolderBookmark: bookmark,
            localFolderDisplayPath: "/Users/me/Documents/Docs",
            remotePath: "macyad-yandex:Docs",
            accountID: accountID ?? self.accountID,
            conflictPolicy: .block,
            scheduleMinutes: 15,
            deletePolicy: .mirrorToYandex,
            lastKnownSeverity: severity,
            lastSyncAt: lastSyncAt,
            lastScheduledSyncAttemptAt: lastSyncAt
        )
    }
}
