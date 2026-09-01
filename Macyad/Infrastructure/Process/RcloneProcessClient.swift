import Foundation

public struct RcloneStreamingHandle: Sendable {
    public let lines: AsyncStream<String>
    public let completion: Task<(stdout: String, stderr: String, exitCode: Int32), Error>
}

public protocol RcloneProcessRunning: Sendable {
    func run(_ arguments: [String]) async throws -> (stdout: String, stderr: String, exitCode: Int32)
    func runStreaming(_ arguments: [String]) async throws -> RcloneStreamingHandle
}

public struct ActiveRcloneCopyOperation: Equatable, Sendable {
    public let pid: Int32
    public let commandLine: String

    public init(pid: Int32, commandLine: String) {
        self.pid = pid
        self.commandLine = commandLine
    }
}

public protocol RcloneOperationInspecting: Sendable {
    func activeCopyOperation(remotePath: String, localPath: String, configPath: String?) async throws -> ActiveRcloneCopyOperation?
}

public struct NoopRcloneOperationInspector: RcloneOperationInspecting {
    public init() {}

    public func activeCopyOperation(remotePath: String, localPath: String, configPath: String?) async throws -> ActiveRcloneCopyOperation? {
        nil
    }
}

public struct SystemRcloneOperationInspector: RcloneOperationInspecting {
    public init() {}

    public func activeCopyOperation(remotePath: String, localPath: String, configPath: String?) async throws -> ActiveRcloneCopyOperation? {
        let result = try await runProcess(
            executablePath: "/usr/bin/pgrep",
            arguments: ["-fal", "rclone"]
        )

        // pgrep returns 1 when there are no matches.
        guard result.exitCode == 0 else {
            return nil
        }

        for line in result.stdout.split(whereSeparator: \.isNewline) {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedLine.isEmpty == false else {
                continue
            }

            let parts = trimmedLine.split(maxSplits: 1, whereSeparator: \.isWhitespace)
            guard parts.count == 2, let pid = Int32(parts[0]) else {
                continue
            }

            let commandLine = String(parts[1])
            guard commandLine.contains("rclone"),
                  commandLine.contains(" copy "),
                  commandLine.contains(remotePath),
                  commandLine.contains(localPath) else {
                continue
            }

            if let configPath, commandLine.contains(configPath) == false {
                continue
            }

            return ActiveRcloneCopyOperation(pid: pid, commandLine: commandLine)
        }

        return nil
    }
}

public struct RcloneProcessClient: RcloneProcessRunning {
    public let executablePath: String

    public init(executablePath: String) {
        self.executablePath = executablePath
    }

    public func run(_ arguments: [String]) async throws -> (stdout: String, stderr: String, exitCode: Int32) {
        try await runProcess(executablePath: executablePath, arguments: arguments)
    }

    public func runStreaming(_ arguments: [String]) async throws -> RcloneStreamingHandle {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let (stream, continuation) = AsyncStream.makeStream(of: String.self, bufferingPolicy: .bufferingNewest(1000))
        let exit = ProcessExit(watching: process)

        // Read both stdout and stderr concurrently, yielding lines from each
        // into the shared stream (rclone writes most operational output to stderr,
        // so the live monitor would stay empty if we only piped stdout).
        let stdoutReader = readToEnd(stdoutPipe.fileHandleForReading, yieldingLinesTo: continuation)
        let stderrReader = readToEnd(stderrPipe.fileHandleForReading, yieldingLinesTo: continuation)

        let completionTask = Task<(stdout: String, stderr: String, exitCode: Int32), Error> {
            let stdoutData = await stdoutReader.value
            let stderrData = await stderrReader.value
            continuation.finish()

            return (
                stdout: String(decoding: stdoutData, as: UTF8.self),
                stderr: String(decoding: stderrData, as: UTF8.self),
                exitCode: try await exit.code()
            )
        }

        do {
            try process.run()
        } catch {
            // Nothing was spawned, so no child ever inherits the write ends and
            // the readers would block on them forever. Close them here and let
            // the exit signal finish so the completion task cannot outlive the
            // failed launch.
            exit.cancel()
            try? stdoutPipe.fileHandleForWriting.close()
            try? stderrPipe.fileHandleForWriting.close()
            throw error
        }

        return RcloneStreamingHandle(lines: stream, completion: completionTask)
    }
}

/// Awaits a child process without ever calling `Process.waitUntilExit()`.
///
/// `waitUntilExit()` drives the run loop of whichever thread calls it, while the
/// child's death is delivered to the thread that called `run()`. Under Swift
/// Concurrency those are two different pool threads as soon as the enclosing
/// task hops, and the wait then never returns: a pull sat at "running…" for six
/// days with no rclone process left alive, and because every manual and
/// scheduled operation goes through `SerialOperationCoordinator`, the queue
/// behind it never moved again. It also blocked a cooperative thread, which
/// Swift Concurrency does not allow.
///
/// `terminationHandler` is installed in `init`, before `run()`, so a child that
/// exits immediately cannot slip past it. The one-slot stream keeps the exit
/// code until somebody asks for it.
private struct ProcessExit: Sendable {
    private let codes: AsyncStream<Int32>
    private let continuation: AsyncStream<Int32>.Continuation

    init(watching process: Process) {
        (codes, continuation) = AsyncStream.makeStream(of: Int32.self, bufferingPolicy: .bufferingNewest(1))
        let continuation = continuation
        process.terminationHandler = { finished in
            continuation.yield(finished.terminationStatus)
            continuation.finish()
        }
    }

    func code() async throws -> Int32 {
        for await code in codes {
            return code
        }
        // Never invent a number here: a synthetic exit code is indistinguishable
        // from one rclone actually returned, and callers branch on it.
        throw ProcessExitUnreported()
    }

    func cancel() {
        continuation.finish()
    }
}

/// The process never reported a status: it failed to launch, or its status was
/// already consumed.
private struct ProcessExitUnreported: Error {}

/// Drains a pipe on a dedicated GCD queue. `FileHandle` reads block, and
/// blocking a thread of the Swift Concurrency pool (which holds one thread per
/// core) is what turns a single stuck read into an app-wide stall.
private func readToEnd(
    _ handle: FileHandle,
    yieldingLinesTo lineContinuation: AsyncStream<String>.Continuation?
) -> Task<Data, Never> {
    Task {
        await withCheckedContinuation { continuation in
            pipeReadQueue.async {
                guard let lineContinuation else {
                    continuation.resume(returning: handle.readDataToEndOfFile())
                    return
                }
                continuation.resume(returning: pumpLines(from: handle, into: lineContinuation))
            }
        }
    }
}

private let pipeReadQueue = DispatchQueue(
    label: "me.orloff.macyad.rclone-pipe-read",
    qos: .utility,
    attributes: .concurrent
)

private func pumpLines(
    from handle: FileHandle,
    into continuation: AsyncStream<String>.Continuation
) -> Data {
    var collected = Data()
    var lineBuffer = ""
    while true {
        let chunk = handle.availableData
        if chunk.isEmpty { break }
        collected.append(chunk)
        guard let text = String(data: chunk, encoding: .utf8) else { continue }
        // Normalize so we yield each carriage-returned progress update
        // (rclone's --stats-one-line uses \r to overwrite the same TTY row
        // and would otherwise accumulate into a single ever-growing line).
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        lineBuffer += normalized
        var lines = lineBuffer.components(separatedBy: "\n")
        lineBuffer = lines.removeLast()
        for line in lines where !line.isEmpty {
            continuation.yield(line)
        }
    }
    if !lineBuffer.isEmpty {
        continuation.yield(lineBuffer)
    }
    return collected
}

private func runProcess(
    executablePath: String,
    arguments: [String]
) async throws -> (stdout: String, stderr: String, exitCode: Int32) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executablePath)
    process.arguments = arguments

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    let exit = ProcessExit(watching: process)
    let stdoutTask = readToEnd(stdoutPipe.fileHandleForReading, yieldingLinesTo: nil)
    let stderrTask = readToEnd(stderrPipe.fileHandleForReading, yieldingLinesTo: nil)

    do {
        try process.run()
    } catch {
        exit.cancel()
        try? stdoutPipe.fileHandleForWriting.close()
        try? stderrPipe.fileHandleForWriting.close()
        throw error
    }

    let stdout = await stdoutTask.value
    let stderr = await stderrTask.value
    return (
        stdout: String(decoding: stdout, as: UTF8.self),
        stderr: String(decoding: stderr, as: UTF8.self),
        exitCode: try await exit.code()
    )
}
