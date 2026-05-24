import XCTest
@testable import MacyadCore

@MainActor
final class CreatePairViewModelTests: XCTestCase {
    private final class StubFolderPicker: FolderPicking {
        func pickFolder() -> (bookmark: Data, displayPath: String)? {
            (Data("bookmark".utf8), "/Users/test/Work Docs")
        }
    }

    func testChooseFolderFillsDisplayPath() {
        let model = CreatePairViewModel(folderPicker: StubFolderPicker(), pairService: PairService())

        model.chooseFolder()

        XCTAssertEqual(model.localFolderDisplayPath, "/Users/test/Work Docs")
        XCTAssertEqual(model.localFolderBookmark, Data("bookmark".utf8))
    }

    func testInitUsesProvidedDefaultSchedule() {
        let model = CreatePairViewModel(
            folderPicker: StubFolderPicker(),
            pairService: PairService(),
            defaultScheduleMinutes: 45
        )

        XCTAssertEqual(model.scheduleMinutes, 45)
    }
}
