import XCTest
@testable import MacyadCore

final class ConfigurationTransferServiceTests: XCTestCase {
    private let service = ConfigurationTransferService()

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
            [ConfigurationImportIssue(pairName: "Docs", kind: .missingLocalFolder(path: "/Users/me/Documents/Docs"))]
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
            id: UUID(),
            displayName: "macyad-yandex",
            remoteName: "macyad-yandex",
            configPath: "/Users/me/.config/rclone/rclone.conf",
            isManaged: false,
            createdAt: Date(timeIntervalSince1970: 1_716_000_000)
        )
    }

    private func makePair(
        name: String = "Docs",
        bookmark: Data = Data(),
        lastSyncAt: Date? = nil,
        severity: Severity = .healthy
    ) -> SyncPair {
        SyncPair(
            id: UUID(),
            name: name,
            localFolderBookmark: bookmark,
            localFolderDisplayPath: "/Users/me/Documents/Docs",
            remotePath: "macyad-yandex:Docs",
            accountID: UUID(),
            conflictPolicy: .block,
            scheduleMinutes: 15,
            deletePolicy: .mirrorToYandex,
            lastKnownSeverity: severity,
            lastSyncAt: lastSyncAt,
            lastScheduledSyncAttemptAt: lastSyncAt
        )
    }
}
