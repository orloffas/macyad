import XCTest
@testable import MacyadCore

final class RcloneProcessClientStreamingTests: XCTestCase {
    func testRunStreamingCollectsLinesInOrder() async throws {
        let client = RcloneProcessClient(executablePath: "/usr/bin/printf")
        let handle = try await client.runStreaming(["line1\nline2\nline3\n"])

        var collectedLines: [String] = []
        for await line in handle.lines {
            collectedLines.append(line)
        }

        let result = try await handle.completion.value
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(collectedLines, ["line1", "line2", "line3"])
    }

    func testRunStreamingExitCodeNonZero() async throws {
        let client = RcloneProcessClient(executablePath: "/bin/sh")
        let handle = try await client.runStreaming(["-c", "printf 'out\n'; exit 42"])

        var collectedLines: [String] = []
        for await line in handle.lines {
            collectedLines.append(line)
        }

        let result = try await handle.completion.value
        XCTAssertEqual(result.exitCode, 42)
        XCTAssertEqual(collectedLines, ["out"])
    }

    func testRunStreamingEmptyOutput() async throws {
        let client = RcloneProcessClient(executablePath: "/usr/bin/true")
        let handle = try await client.runStreaming([])

        var collectedLines: [String] = []
        for await line in handle.lines {
            collectedLines.append(line)
        }

        let result = try await handle.completion.value
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(collectedLines.isEmpty)
    }

    func testRunStreamingSplitsCarriageReturnProgressUpdates() async throws {
        // rclone's --stats-one-line emits progress with \r overwrites; ensure
        // each update is yielded as its own line instead of accumulating.
        let client = RcloneProcessClient(executablePath: "/bin/sh")
        let handle = try await client.runStreaming([
            "-c",
            "printf 'progress1\\rprogress2\\rprogress3\\n'"
        ])

        var collectedLines: [String] = []
        for await line in handle.lines {
            collectedLines.append(line)
        }

        let result = try await handle.completion.value
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(collectedLines, ["progress1", "progress2", "progress3"])
    }

    func testRunStreamingMergesStderrIntoLineStream() async throws {
        // rclone writes most operational output to stderr, so the streaming
        // handle must merge both pipes into the same line stream — otherwise
        // the live monitor stays empty during real syncs.
        let client = RcloneProcessClient(executablePath: "/bin/sh")
        let handle = try await client.runStreaming([
            "-c",
            "printf 'out-line\\n'; printf 'err-line\\n' 1>&2"
        ])

        var collectedLines: [String] = []
        for await line in handle.lines {
            collectedLines.append(line)
        }

        let result = try await handle.completion.value
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(
            collectedLines.contains("out-line"),
            "stdout line missing from merged stream: \(collectedLines)"
        )
        XCTAssertTrue(
            collectedLines.contains("err-line"),
            "stderr line missing from merged stream: \(collectedLines)"
        )
        XCTAssertEqual(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "out-line")
        XCTAssertEqual(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines), "err-line")
    }
}
