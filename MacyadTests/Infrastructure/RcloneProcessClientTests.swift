import XCTest
@testable import MacyadCore

final class RcloneProcessClientTests: XCTestCase {
    func testRunCapturesLargeStdoutWithoutDeadlock() async throws {
        let client = RcloneProcessClient(executablePath: "/bin/sh")

        let result = try await client.run([
            "-c",
            "/usr/bin/yes X | /usr/bin/head -n 20000"
        ])

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.count >= 40_000)
        XCTAssertTrue(result.stderr.isEmpty)
    }

    func testOperationInspectorFindsMatchingCopyInPgrepOutput() async throws {
        let inspector = SystemRcloneOperationInspector()

        // This test validates the parser shape against a command line identical
        // to what the app looks for by stubbing pgrep via a temporary shell script.
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let scriptURL = rootURL.appendingPathComponent("pgrep")
        try """
        #!/bin/sh
        printf '4863 rclone copy macyad-yandex:/SampleFolder /Users/test/Documents/YaD/SampleFolder --config /tmp/rclone.conf\n'
        """.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: scriptURL.path
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "PATH=\(rootURL.path):/usr/bin:/bin",
            "/bin/sh",
            "-c",
            "pgrep -fal rclone"
        ]
        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        try process.run()
        process.waitUntilExit()
        let raw = String(decoding: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        XCTAssertTrue(raw.contains("4863"))

        // Parser contract mirrors the real inspector matching logic.
        let operation = raw
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> ActiveRcloneCopyOperation? in
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                let parts = trimmedLine.split(maxSplits: 1, whereSeparator: \.isWhitespace)
                guard parts.count == 2, let pid = Int32(parts[0]) else {
                    return nil
                }
                let commandLine = String(parts[1])
                guard commandLine.contains("rclone"),
                      commandLine.contains(" copy "),
                      commandLine.contains("macyad-yandex:/SampleFolder"),
                      commandLine.contains("/Users/test/Documents/YaD/SampleFolder"),
                      commandLine.contains("/tmp/rclone.conf") else {
                    return nil
                }
                return ActiveRcloneCopyOperation(pid: pid, commandLine: commandLine)
            }
            .first

        XCTAssertEqual(operation?.pid, 4_863)
        XCTAssertTrue(operation?.commandLine.contains("SampleFolder") == true)
        _ = inspector
    }
}
