import XCTest
@testable import MacyadCore

final class SerialOperationCoordinatorTests: XCTestCase {
    func testEnqueueRunsOperationsStrictlyInOrder() async throws {
        let recorder = Recorder()
        let coordinator = SerialOperationCoordinator()
        let firstStarted = Signal()
        let releaseFirst = Signal()

        let first = Task {
            try await coordinator.enqueue(pairID: UUID(), label: "first") {
                await recorder.append("first-start")
                await firstStarted.open()
                await releaseFirst.wait()
                await recorder.append("first-end")
                return 1
            }
        }

        await firstStarted.wait()

        let second = Task {
            try await coordinator.enqueue(pairID: UUID(), label: "second") {
                await recorder.append("second-start")
                await recorder.append("second-end")
                return 2
            }
        }

        while await coordinator.states().count < 2 {
            await Task.yield()
        }

        await releaseFirst.open()

        let values = try await [first.value, second.value]
        let events = await recorder.events()

        XCTAssertEqual(values, [1, 2])
        XCTAssertEqual(events, ["first-start", "first-end", "second-start", "second-end"])
    }

    func testConcurrentEnqueuesNeverOverlap() async throws {
        // Push All enqueues every pair at once from separate tasks. A suspension inside
        // `enqueue` before the queue tail is taken lets two callers chain onto the same
        // tail and run side by side — two rclone runs where one was promised.
        let coordinator = SerialOperationCoordinator()
        let overlap = OverlapMeter()

        await withTaskGroup(of: Void.self) { group in
            for index in 0..<100 {
                group.addTask {
                    _ = try? await coordinator.enqueue(pairID: nil, label: "op-\(index)") {
                        await overlap.enter()
                        try? await Task.sleep(for: .milliseconds(2))
                        await overlap.leave()
                    }
                }
            }
        }

        let peak = await overlap.peak
        let finished = await overlap.finished
        XCTAssertEqual(finished, 100)
        XCTAssertEqual(peak, 1, "operations ran side by side")
    }

    func testStatesExposeQueuedAndRunningOperations() async throws {
        let coordinator = SerialOperationCoordinator()
        let gate = Gate()

        Task {
            _ = try? await coordinator.enqueue(pairID: UUID(), label: "blocked") {
                await gate.wait()
                return 1
            }
        }

        try? await Task.sleep(for: .milliseconds(25))

        Task {
            _ = try? await coordinator.enqueue(pairID: UUID(), label: "queued") { 2 }
        }

        try? await Task.sleep(for: .milliseconds(25))
        let states = await coordinator.states()
        await gate.open()

        XCTAssertEqual(states.first?.phase, .running)
        XCTAssertEqual(states.dropFirst().first?.phase, .queued)
        XCTAssertEqual(states.map(\.label), ["blocked", "queued"])
    }
}

private actor OverlapMeter {
    private var active = 0
    private(set) var peak = 0
    private(set) var finished = 0

    func enter() {
        active += 1
        peak = max(peak, active)
    }

    func leave() {
        active -= 1
        finished += 1
    }
}

private actor Recorder {
    private var storage: [String] = []

    func append(_ value: String) {
        storage.append(value)
    }

    func events() -> [String] {
        storage
    }
}

private actor Gate {
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func open() {
        continuation?.resume()
        continuation = nil
    }
}

private actor Signal {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else {
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func open() {
        guard !isOpen else {
            return
        }

        isOpen = true
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }
}
