import XCTest
@testable import MacyadCore

final class RcloneErrorExplainerTests: XCTestCase {
    private let copy = AppCopy(language: .russian)
    private let pushCommand = ["--config", "/Users/test/rclone.conf", "sync", "/Users/test/Docs", "yandex:Docs"]

    func testOnlyNetworkFailuresAreTransient() {
        // Verbatim from a scheduled push on 22.11.2026, when DNS was gone for every pair.
        let dns = #"ERROR : error listing: Get "https://cloud-api.yandex.com/v1/disk/resources?limit=1000": dial tcp: lookup cloud-api.yandex.com: no such host"#
        XCTAssertTrue(RcloneErrorExplainer.isTransientNetworkFailure(stderr: dns))
        XCTAssertTrue(RcloneErrorExplainer.isTransientNetworkFailure(stderr: "read tcp 10.0.0.2:5123->1.2.3.4:443: read: connection reset by peer"))
        XCTAssertFalse(RcloneErrorExplainer.isTransientNetworkFailure(stderr: "Failed to sync: GoneError: Resource is gone (410)"))
        XCTAssertFalse(RcloneErrorExplainer.isTransientNetworkFailure(stderr: "couldn't fetch token: invalid_grant"))
        XCTAssertFalse(RcloneErrorExplainer.isTransientNetworkFailure(stderr: "permission denied"))
        // A lasting cause wins over a network line about another item in the same run.
        XCTAssertFalse(RcloneErrorExplainer.isTransientNetworkFailure(stderr: "GoneError: Resource is gone (410)\n" + dns))
    }

    func testGoneErrorPointsToOwnOAuthApp() throws {
        let stderr = "2026/11/19 10:03:44 ERROR : Docs/a.txt: Failed to copy: 410 - GoneError: resource gone"
        let result = try XCTUnwrap(RcloneErrorExplainer.explain(stderr: stderr, command: pushCommand, copy: copy))
        XCTAssertTrue(result.headline.contains("410"))
        XCTAssertTrue(result.advice.contains("Reconnect account"))
        XCTAssertTrue(result.advice.contains("yandex-oauth-app"))
    }

    func testDuplicateDirectoryNamesTheFolder() throws {
        let stderr = "Сиреневый Парк: Duplicate directory found in destination - ignoring"
        let result = try XCTUnwrap(RcloneErrorExplainer.explain(stderr: stderr, command: pushCommand, copy: copy))
        XCTAssertTrue(result.headline.contains("«Сиреневый Парк»"))
        XCTAssertTrue(result.advice.contains("disk.yandex.ru"))
    }

    func testDuplicateDirectoryStripsLogPrefix() throws {
        let stderr = "2026/11/19 10:03:44 NOTICE: Фото/Лето: Duplicate directory found in destination - ignoring"
        let result = try XCTUnwrap(RcloneErrorExplainer.explain(stderr: stderr, copy: copy))
        XCTAssertTrue(result.headline.contains("«Фото/Лето»"))
    }

    func testAuthFailures() throws {
        for stderr in ["Failed: 401 Unauthorized", "oauth2: invalid_grant", "couldn't fetch token: bad", "token expired"] {
            let result = try XCTUnwrap(RcloneErrorExplainer.explain(stderr: stderr, copy: copy), stderr)
            XCTAssertEqual(result.headline, copy.rcloneErrorAuthHeadline)
        }
    }

    func testDirectoryNotFoundOnRemoteByRcloneObjectPrefix() throws {
        let stderr = "2026/11/19 10:03:44 ERROR : Yandex root: error reading source root directory: directory not found"
        let result = try XCTUnwrap(RcloneErrorExplainer.explain(stderr: stderr, command: pushCommand, copy: copy))
        XCTAssertEqual(result.headline, copy.rcloneErrorRemoteMissingHeadline)
    }

    func testDirectoryNotFoundOnRemoteSourceByCommand() throws {
        let pull = ["sync", "yandex:Docs", "/Users/test/Docs"]
        let stderr = "2026/11/19 10:03:44 ERROR : : error reading source root directory: directory not found"
        let result = try XCTUnwrap(RcloneErrorExplainer.explain(stderr: stderr, command: pull, copy: copy))
        XCTAssertEqual(result.headline, copy.rcloneErrorRemoteMissingHeadline)
    }

    func testDirectoryNotFoundOnLocalSourceByCommand() throws {
        let stderr = "2026/11/19 10:03:44 ERROR : : error reading source root directory: directory not found"
        let result = try XCTUnwrap(RcloneErrorExplainer.explain(stderr: stderr, command: pushCommand, copy: copy))
        XCTAssertEqual(result.headline, copy.rcloneErrorLocalMissingHeadline)
    }

    func testDirectoryNotFoundLocalFileSystemMarker() throws {
        let stderr = "ERROR : Local file system at /Users/test/Docs: error reading source root directory: directory not found"
        let result = try XCTUnwrap(RcloneErrorExplainer.explain(stderr: stderr, command: [], copy: copy))
        XCTAssertEqual(result.headline, copy.rcloneErrorLocalMissingHeadline)
    }

    func testUnknownErrorIsNotExplained() {
        XCTAssertNil(RcloneErrorExplainer.explain(stderr: "ERROR : something odd", copy: copy))
    }

    func testNormalizationDuplicatesDetectsNFDAndNFCTwins() {
        let nfc = "Сиреневый Парк".precomposedStringWithCanonicalMapping
        let nfd = "Сиреневый Парк".decomposedStringWithCanonicalMapping
        XCTAssertEqual(nfc, nfd) // Swift treats them as equal; the detector must not
        XCTAssertNotEqual(Array(nfc.unicodeScalars), Array(nfd.unicodeScalars))

        let found = RcloneErrorExplainer.normalizationDuplicates(in: ["\(nfc)/a.txt", "\(nfd)/b.txt", "Other/c.txt"])
        XCTAssertEqual(found.count, 1)
    }

    func testNormalizationDuplicatesIgnoresDistinctPaths() {
        XCTAssertTrue(RcloneErrorExplainer.normalizationDuplicates(in: ["A/a.txt", "A/b.txt", "B/c.txt"]).isEmpty)
    }

    func testNormalizationDuplicatesReportsOnlyShallowestLevel() {
        let nfc = "Дворовый".precomposedStringWithCanonicalMapping
        let nfd = "Дворовый".decomposedStringWithCanonicalMapping
        XCTAssertEqual(RcloneErrorExplainer.normalizationDuplicates(in: ["\(nfc)/Sub/a", "\(nfd)/Sub/b"]).count, 1)
    }

    func testCommandFailedErrorPutsAdviceAboveRawOutput() {
        let error = SyncService.CommandFailedError(
            command: ["sync"], exitCode: 1, stderr: "Папка: Duplicate directory found in destination - ignoring"
        )
        XCTAssertFalse(error.summaryDescription.contains("rclone"))
        let details = error.detailedDescription
        let advice = details.range(of: "disk.yandex.ru")
        let raw = details.range(of: "Duplicate directory found")
        XCTAssertNotNil(advice)
        XCTAssertNotNil(raw)
        if let advice, let raw { XCTAssertLessThan(advice.lowerBound, raw.lowerBound) }
        XCTAssertTrue(details.contains("———"))
    }
}
