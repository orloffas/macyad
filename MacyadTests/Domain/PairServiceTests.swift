import XCTest
@testable import MacyadCore

final class PairServiceTests: XCTestCase {
    func testCreateRejectsEmptyRemotePath() throws {
        let service = PairService()

        XCTAssertThrowsError(
            try service.makePair(
                name: "Work Docs",
                localFolderBookmark: Data("bookmark".utf8),
                localFolderDisplayPath: "/Users/test/Work Docs",
                remotePath: "",
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
                scheduleMinutes: 30,
                deletePolicy: .mirrorToYandex
            )
        ) { error in
            XCTAssertEqual(error as? PairService.ValidationError, .missingLocalFolder)
        }
    }
}
