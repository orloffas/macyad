import Darwin
import XCTest
@testable import MacyadCore

/// Stand for the "running…" hang: thousands of real child processes through
/// `RcloneProcessClient`, several at once, the way a queue of runs plus the
/// pgrep inspector spawn them. A rare lost wakeup only shows up in bulk — the
/// previous hang of this kind needed 15 of 300 iterations to appear.
///
/// Off by default (minutes of runtime). Run with:
/// `TEST_RUNNER_MACYAD_STRESS=2000 ./script/test.sh unit`
final class RcloneProcessClientStressTests: XCTestCase {
    private static let script = """
    i=0
    while [ $i -lt 40 ]; do echo "stdout line $i Схемы—"; echo "stderr line $i" >&2; i=$((i+1)); done
    sleep 0.$((RANDOM % 10))
    exit 3
    """

    func testEveryChildIsReapedAndEveryPipeEnds() async throws {
        let raw = ProcessInfo.processInfo.environment["MACYAD_STRESS"] ?? ""
        guard let iterations = Int(raw), iterations > 0 else {
            throw XCTSkip("set TEST_RUNNER_MACYAD_STRESS=<iterations> to run the stand")
        }
        let client = RcloneProcessClient(executablePath: "/bin/sh")
        // Children outlive the call that spawned them (the sleep above), as a real rclone does:
        // by then nothing in our code holds the `Process` any more.
        let width = 16
        var hangs: [String] = []

        for batch in stride(from: 0, to: iterations, by: width) {
            let results = await withTaskGroup(of: String?.self) { group in
                for index in batch..<min(batch + width, iterations) {
                    group.addTask {
                        await Self.iteration(index, client: client)
                    }
                }
                var found: [String] = []
                for await result in group {
                    if let result { found.append(result) }
                }
                return found
            }
            hangs.append(contentsOf: results)
            if hangs.count >= 3 { break }
        }

        XCTAssertEqual(hangs, [], "hung iterations")
    }

    /// nil when the iteration finished; a description of the stuck stage otherwise.
    private static func iteration(_ index: Int, client: RcloneProcessClient) async -> String? {
        let streaming = index.isMultiple(of: 2)
        let work = Task { () -> Int32 in
            if streaming {
                let handle = try await client.runStreaming(["-c", script])
                var lines = 0
                for await _ in handle.lines { lines += 1 }
                return try await handle.completion.value.exitCode
            }
            return try await client.run(["-c", script]).exitCode
        }
        let finished = await withTaskGroup(of: Int32?.self) { group in
            group.addTask { try? await work.value }
            group.addTask {
                try? await Task.sleep(for: .seconds(15))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        if finished == 3 { return nil }
        if finished != nil { return "#\(index) wrong exit code \(finished!)" }
        return "#\(index) (\(streaming ? "runStreaming" : "run")) hung; children of this process: \(childStates())"
    }

    /// `ps` rows for children of the test process: a `Z` state means the child
    /// exited and nobody reaped it, so `terminationHandler` never fired.
    private static func childStates() -> String {
        let ps = Process()
        ps.executableURL = URL(fileURLWithPath: "/bin/ps")
        ps.arguments = ["-o", "pid=,stat=,ppid=,command=", "-g", String(getpgrp())]
        let pipe = Pipe()
        ps.standardOutput = pipe
        try? ps.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let me = String(getpid())
        return String(decoding: data, as: UTF8.self)
            .split(separator: "\n")
            .filter { $0.split(separator: " ", omittingEmptySubsequences: true).dropFirst(2).first.map(String.init) == me }
            .joined(separator: " | ")
    }
}
