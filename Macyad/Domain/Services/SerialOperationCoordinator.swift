import Foundation

public actor SerialOperationCoordinator {
    public struct OperationState: Equatable, Sendable {
        public enum Phase: String, Equatable, Sendable {
            case queued
            case running
        }

        public let id: UUID
        public let pairID: UUID?
        public let label: String
        public let phase: Phase
    }

    public typealias StateDidChange = @Sendable ([OperationState]) async -> Void

    private let stateDidChange: StateDidChange
    private var queuedStates: [OperationState] = []
    private var runningState: OperationState?
    private var tail: Task<Void, Never>?

    public init(stateDidChange: @escaping StateDidChange = { _ in }) {
        self.stateDidChange = stateDidChange
    }

    public func enqueue<T: Sendable>(
        pairID: UUID?,
        label: String,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let operationID = UUID()
        let state = OperationState(id: operationID, pairID: pairID, label: label, phase: .queued)
        queuedStates.append(state)
        await notifyStateChanged()

        let previousTail = tail
        let resultTask = Task<T, Error> {
            if let previousTail {
                await previousTail.value
            }

            await self.markRunning(operationID: operationID)
            do {
                let value = try await operation()
                await self.clearRunning(operationID: operationID)
                return value
            } catch {
                await self.clearRunning(operationID: operationID)
                throw error
            }
        }

        tail = Task {
            _ = try? await resultTask.value
        }

        return try await resultTask.value
    }

    public func states() -> [OperationState] {
        var result = runningState.map { [$0] } ?? []
        result += queuedStates
        return result
    }

    private func markRunning(operationID: UUID) async {
        if let index = queuedStates.firstIndex(where: { $0.id == operationID }) {
            let entry = queuedStates.remove(at: index)
            runningState = OperationState(id: entry.id, pairID: entry.pairID, label: entry.label, phase: .running)
            await notifyStateChanged()
        }
    }

    private func clearRunning(operationID: UUID) async {
        if runningState?.id == operationID {
            runningState = nil
        }
        await notifyStateChanged()
    }

    private func notifyStateChanged() async {
        await stateDidChange(states())
    }
}
