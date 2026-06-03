import Foundation
import Combine

@MainActor
public final class LiveMonitorViewModel: ObservableObject {
    @Published public private(set) var lines: [String] = []
    @Published public private(set) var exitStatus: ExitStatus?

    public enum ExitStatus: Sendable {
        case success
        case failed(code: Int32)
    }

    private let maxLines = 5000
    private var subscriptionTask: Task<Void, Never>?
    private var completionTask: Task<Void, Never>?

    public init() {}

    public func attach(handle: RcloneStreamingHandle) {
        cancelExistingSubscriptions()
        exitStatus = nil
        subscriptionTask = Task { @MainActor [weak self] in
            for await line in handle.lines {
                guard let self else { return }
                self.lines.append(line)
                if self.lines.count > self.maxLines {
                    self.lines.removeFirst(self.lines.count - self.maxLines)
                }
            }
        }
        completionTask = Task { @MainActor [weak self] in
            guard let result = try? await handle.completion.value else { return }
            self?.exitStatus = (result.exitCode == 0) ? .success : .failed(code: result.exitCode)
        }
    }

    public func appendLine(_ line: String) {
        lines.append(line)
        if lines.count > maxLines {
            lines.removeFirst(lines.count - maxLines)
        }
    }

    public func setExitStatus(_ status: ExitStatus) {
        self.exitStatus = status
    }

    public func clearAndRestart(handle: RcloneStreamingHandle) {
        cancelExistingSubscriptions()
        lines.removeAll()
        attach(handle: handle)
    }

    private func cancelExistingSubscriptions() {
        subscriptionTask?.cancel(); subscriptionTask = nil
        completionTask?.cancel(); completionTask = nil
    }

    deinit {
        subscriptionTask?.cancel()
        completionTask?.cancel()
    }
}
