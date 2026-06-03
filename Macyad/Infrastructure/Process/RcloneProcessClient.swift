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

        let completionTask = Task<(stdout: String, stderr: String, exitCode: Int32), Error> {
            // Read both stdout and stderr concurrently, yielding lines from each
            // into the shared stream (rclone writes most operational output to stderr,
            // so the live monitor would stay empty if we only piped stdout).
            let stdoutReader = Task.detached(priority: .utility) {
                pumpLines(from: stdoutPipe.fileHandleForReading, into: continuation)
            }
            let stderrReader = Task.detached(priority: .utility) {
                pumpLines(from: stderrPipe.fileHandleForReading, into: continuation)
            }

            let stdoutData = await stdoutReader.value
            let stderrData = await stderrReader.value
            continuation.finish()

            process.waitUntilExit()

            return (
                stdout: String(decoding: stdoutData, as: UTF8.self),
                stderr: String(decoding: stderrData, as: UTF8.self),
                exitCode: process.terminationStatus
            )
        }

        try process.run()

        return RcloneStreamingHandle(lines: stream, completion: completionTask)
    }
}

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

    let stdoutTask = Task.detached(priority: .utility) {
        stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    }
    let stderrTask = Task.detached(priority: .utility) {
        stderrPipe.fileHandleForReading.readDataToEndOfFile()
    }

    try process.run()
    process.waitUntilExit()

    let stdout = await stdoutTask.value
    let stderr = await stderrTask.value
    return (
        stdout: String(decoding: stdout, as: UTF8.self),
        stderr: String(decoding: stderr, as: UTF8.self),
        exitCode: process.terminationStatus
    )
}
