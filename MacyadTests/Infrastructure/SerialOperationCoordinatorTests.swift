import XCTest
@testable import MacyadCore

final class SerialOperationCoordinatorTests: XCTestCase {
    func testEnqueueRunsOperationsStrictlyInOrder() async throws {
        let recorder = Recorder()
        let coordinator = SerialOperationCoordinator()

        async let first: Int = coordinator.enqueue(pairID: UUID(), label: "first") {
            await recorder.append("first-start")
            try? await Task.sleep(for: .milliseconds(50))
            await recorder.append("first-end")
            return 1
        }

        async let second: Int = coordinator.enqueue(pairID: UUID(), label: "second") {
            await recorder.append("second-start")
            await recorder.append("second-end")
            return 2
        }

        let values = try await [first, second]
        let events = await recorder.events()

        XCTAssertEqual(values, [1, 2])
        XCTAssertEqual(events, ["first-start", "first-end", "second-start", "second-end"])
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
