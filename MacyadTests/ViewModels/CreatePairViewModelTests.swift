import XCTest
@testable import MacyadCore

@MainActor
final class CreatePairViewModelTests: XCTestCase {
    private var account: YandexAccount {
        YandexAccount(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            displayName: "Primary",
            remoteName: "yd-primary",
            configPath: "/tmp/rclone.conf",
            isManaged: true
        )
    }

    private final class StubFolderPicker: FolderPicking {
        func pickFolder() -> (bookmark: Data, displayPath: String)? {
            (Data("bookmark".utf8), "/Users/test/Work Docs")
        }
    }

    func testChooseFolderFillsDisplayPath() {
        let model = CreatePairViewModel(
            accounts: [account],
            folderPicker: StubFolderPicker(),
            pairService: PairService()
        )

        model.chooseFolder()

        XCTAssertEqual(model.localFolderDisplayPath, "/Users/test/Work Docs")
        XCTAssertEqual(model.localFolderBookmark, Data("bookmark".utf8))
    }

    func testInitUsesProvidedDefaultSchedule() {
        let model = CreatePairViewModel(
            accounts: [account],
            folderPicker: StubFolderPicker(),
            pairService: PairService(),
            defaultScheduleMinutes: 45
        )

        XCTAssertEqual(model.scheduleMinutes, 45)
        XCTAssertEqual(model.selectedAccountID, account.id)
    }

    func testInitFromExistingPairPopulatesEditableFields() {
        let existingPair = SyncPair(
            id: UUID(),
            name: "Docs",
            localFolderBookmark: Data("bookmark".utf8),
            localFolderDisplayPath: "/Users/test/Docs",
            remotePath: "yd-primary:/docs",
            accountID: account.id,
            conflictPolicy: .keepBoth,
            scheduleMinutes: 20,
            deletePolicy: .keepRemoteDeletesManual,
            lastKnownSeverity: .warning,
            syncExcludes: [".DS_Store", "*.tmp"],
            checkAdditionalExcludes: ["Desktop.ini"]
        )

        let model = CreatePairViewModel(
            existingPair: existingPair,
            accounts: [account],
            folderPicker: StubFolderPicker(),
            pairService: PairService()
        )

        XCTAssertTrue(model.isEditing)
        XCTAssertEqual(model.name, "Docs")
        XCTAssertEqual(model.localFolderBookmark, Data("bookmark".utf8))
        XCTAssertEqual(model.localFolderDisplayPath, "/Users/test/Docs")
        XCTAssertEqual(model.selectedAccountID, account.id)
        XCTAssertEqual(model.remoteSubpath, "docs")
        XCTAssertEqual(model.resolvedRemotePath, "yd-primary:/docs")
        XCTAssertEqual(model.conflictPolicy, .keepBoth)
        XCTAssertEqual(model.scheduleMinutes, 20)
        XCTAssertEqual(model.deletePolicy, .keepRemoteDeletesManual)
        XCTAssertEqual(model.syncExcludesText, ".DS_Store\n*.tmp")
        XCTAssertEqual(model.checkAdditionalExcludesText, "Desktop.ini")
    }

    func testBuildPairParsesDeduplicatedExcludesAndPreservesEditedPairIdentity() throws {
        let existingPair = SyncPair(
            id: UUID(),
            name: "Docs",
            localFolderBookmark: Data("bookmark".utf8),
            localFolderDisplayPath: "/Users/test/Docs",
            remotePath: "yd-primary:/docs",
            accountID: account.id,
            conflictPolicy: .block,
            scheduleMinutes: 20,
            deletePolicy: .mirrorToYandex,
            lastKnownSeverity: .alarm,
            lastSyncAt: Date(timeIntervalSince1970: 1_234),
            syncExcludes: [".DS_Store"],
            checkAdditionalExcludes: []
        )

        let model = CreatePairViewModel(
            existingPair: existingPair,
            accounts: [account],
            folderPicker: StubFolderPicker(),
            pairService: PairService()
        )
        model.syncExcludesText = ".DS_Store\nThumbs.db\nThumbs.db\n\n*.tmp  "
        model.checkAdditionalExcludesText = "Desktop.ini\n\nDesktop.ini\n*.bak"

        let updatedPair = try model.buildPair()

        XCTAssertEqual(updatedPair.id, existingPair.id)
        XCTAssertEqual(updatedPair.lastKnownSeverity, Severity.alarm)
        XCTAssertEqual(updatedPair.lastSyncAt, existingPair.lastSyncAt)
        XCTAssertEqual(updatedPair.accountID, account.id)
        XCTAssertEqual(updatedPair.conflictPolicy, .block)
        XCTAssertEqual(updatedPair.syncExcludes, [".DS_Store", "Thumbs.db", "*.tmp"])
        XCTAssertEqual(updatedPair.checkAdditionalExcludes, ["Desktop.ini", "*.bak"])
    }
}
