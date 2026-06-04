import XCTest
@testable import MacyadCore

@MainActor
final class LiveMonitorViewModelTests: XCTestCase {
    func testAttachCollectsLinesFromStream() async {
        let vm = LiveMonitorViewModel()
        let lines = ["alpha", "beta", "gamma"]
        let handle = makeHandle(lines: lines, exitCode: 0)

        vm.attach(handle: handle)
        await waitUntil(vm, lineCount: lines.count)

        XCTAssertEqual(vm.lines, lines)
        await waitForExitStatus(vm)
        if case .success = vm.exitStatus { } else {
            XCTFail("Expected exitStatus == .success, got \(String(describing: vm.exitStatus))")
        }
    }

    func testRollingCapDropsOldestLinesViaAppendLine() {
        // Tests rolling cap logic directly without async timing concerns.
        // The attach() path uses the same appendLine-equivalent code so this
        // covers the invariant: only last 5000 lines are retained.
        let vm = LiveMonitorViewModel()
        let count = 6000
        for i in 0..<count {
            vm.appendLine("line\(i)")
        }
        XCTAssertEqual(vm.lines.count, 5000)
        XCTAssertEqual(vm.lines.first, "line1000")
        XCTAssertEqual(vm.lines.last, "line5999")
    }

    func testExitStatusFailedOnNonZeroCode() async {
        let vm = LiveMonitorViewModel()
        let handle = makeHandle(lines: [], exitCode: 42)

        vm.attach(handle: handle)
        await waitForExitStatus(vm)

        if case .failed(let code) = vm.exitStatus {
            XCTAssertEqual(code, 42)
        } else {
            XCTFail("Expected exitStatus == .failed(42), got \(String(describing: vm.exitStatus))")
        }
    }

    func testClearAndRestartResetsAndAttachesNewStream() async {
        let vm = LiveMonitorViewModel()
        let firstHandle = makeHandle(lines: ["old1", "old2"], exitCode: 0)
        vm.attach(handle: firstHandle)
        await waitUntil(vm, lineCount: 2)
        await waitForExitStatus(vm)

        XCTAssertEqual(vm.lines.count, 2)

        let secondHandle = makeHandle(lines: ["new1"], exitCode: 0)
        vm.clearAndRestart(handle: secondHandle)
        await waitUntil(vm, lineCount: 1)

        XCTAssertEqual(vm.lines, ["new1"])
    }

    func testAppendLineDirect() {
        let vm = LiveMonitorViewModel()
        vm.appendLine("hello")
        vm.appendLine("world")
        XCTAssertEqual(vm.lines, ["hello", "world"])
    }

    func testAppendLineRollingCap() {
        let vm = LiveMonitorViewModel()
        for i in 0..<5001 {
            vm.appendLine("line\(i)")
        }
        XCTAssertEqual(vm.lines.count, 5000)
        XCTAssertEqual(vm.lines.first, "line1")
        XCTAssertEqual(vm.lines.last, "line5000")
    }

    func testClearLogResetsLinesAndExitStatus() {
        let vm = LiveMonitorViewModel()
        vm.appendLine("first")
        vm.appendLine("second")
        vm.setExitStatus(.failed(code: 3))
        XCTAssertEqual(vm.lines.count, 2)
        XCTAssertNotNil(vm.exitStatus)

        vm.clearLog()

        XCTAssertTrue(vm.lines.isEmpty)
        XCTAssertNil(vm.exitStatus)
    }

    func testSetExitStatus() {
        let vm = LiveMonitorViewModel()
        XCTAssertNil(vm.exitStatus)
        vm.setExitStatus(.success)
        if case .success = vm.exitStatus { } else {
            XCTFail("Expected .success")
        }
        vm.setExitStatus(.failed(code: 7))
        if case .failed(let code) = vm.exitStatus {
            XCTAssertEqual(code, 7)
        } else {
            XCTFail("Expected .failed(7)")
        }
    }

    // MARK: - Helpers

    private func waitUntil(_ vm: LiveMonitorViewModel, lineCount: Int) async {
        for _ in 0..<2000 {
            if vm.lines.count >= lineCount { return }
            await Task.yield()
        }
    }

    private func waitForExitStatus(_ vm: LiveMonitorViewModel) async {
        for _ in 0..<2000 {
            if vm.exitStatus != nil { return }
            await Task.yield()
        }
    }

    private func waitUntilLineCountStabilizes(_ vm: LiveMonitorViewModel, expectedMax: Int) async {
        // Wait until lines stop growing (stream fully drained and cap applied)
        var previousCount = -1
        var stableIterations = 0
        for _ in 0..<5000 {
            let current = vm.lines.count
            if current == previousCount {
                stableIterations += 1
                if stableIterations >= 10 { return }
            } else {
                stableIterations = 0
                previousCount = current
            }
            await Task.yield()
        }
    }

    private func makeHandle(lines: [String], exitCode: Int32) -> RcloneStreamingHandle {
        let (stream, continuation) = AsyncStream.makeStream(of: String.self)
        let capturedLines = lines
        let completionTask = Task<(stdout: String, stderr: String, exitCode: Int32), Error> {
            for line in capturedLines {
                continuation.yield(line)
            }
            continuation.finish()
            return ("", "", exitCode)
        }
        return RcloneStreamingHandle(lines: stream, completion: completionTask)
    }

    // Sequential handle: completes only after stream is fully consumed by awaiting finish
    private func makeHandleSequential(lines: [String], exitCode: Int32) -> RcloneStreamingHandle {
        let (stream, continuation) = AsyncStream.makeStream(of: String.self, bufferingPolicy: .unbounded)
        let capturedLines = lines
        let completionTask = Task<(stdout: String, stderr: String, exitCode: Int32), Error> {
            for line in capturedLines {
                continuation.yield(line)
                await Task.yield()
            }
            continuation.finish()
            // Yield many times to let subscriptionTask drain all items before returning
            for _ in 0..<200 { await Task.yield() }
            return ("", "", exitCode)
        }
        return RcloneStreamingHandle(lines: stream, completion: completionTask)
    }

    private func drainTasks() async {
        // Yield control multiple times to let spawned Tasks complete
        for _ in 0..<20 {
            await Task.yield()
        }
    }
}
