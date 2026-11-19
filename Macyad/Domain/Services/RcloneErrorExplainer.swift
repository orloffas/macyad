import Foundation

/// Maps raw rclone stderr to a human explanation and a next step.
/// Pure: no I/O, so every mapping is covered by unit tests.
public enum RcloneErrorExplainer {
    public struct Explanation: Equatable, Sendable {
        public let headline: String
        public let advice: String
    }

    // Options whose next argument is a value, not a path.
    private static let valuedFlags: Set<String> = ["--config", "--exclude-from", "--exclude", "--hash-type"]

    private static let authMarkers = [
        "401 unauthorized", "error 401", "invalid_grant", "token expired",
        "couldn't fetch token", "failed to refresh token"
    ]

    /// Returns nil when stderr matches no known cause (callers keep the generic headline).
    public static func explain(
        stderr: String,
        command: [String] = [],
        copy: AppCopy = .current
    ) -> Explanation? {
        let lowered = stderr.lowercased()

        if lowered.contains("goneerror") {
            return Explanation(headline: copy.rcloneErrorGoneHeadline, advice: copy.rcloneErrorGoneAdvice)
        }
        if let folder = duplicateFolderName(in: stderr) {
            return Explanation(
                headline: copy.rcloneErrorDuplicateHeadline(folder: folder),
                advice: copy.rcloneErrorDuplicateAdvice
            )
        }
        if authMarkers.contains(where: lowered.contains) {
            return Explanation(headline: copy.rcloneErrorAuthHeadline, advice: copy.rcloneErrorAuthAdvice)
        }
        if lowered.contains("directory not found") {
            return isLocalPathFailure(stderr: lowered, command: command)
                ? Explanation(headline: copy.rcloneErrorLocalMissingHeadline, advice: copy.rcloneErrorLocalMissingAdvice)
                : Explanation(headline: copy.rcloneErrorRemoteMissingHeadline, advice: copy.rcloneErrorRemoteMissingAdvice)
        }
        return nil
    }

    /// Folders (or files) listed twice that differ only in Unicode normalization. Swift `String`
    /// equality treats such names as equal, so variants are told apart by their scalars.
    /// Only the shallowest level is reported: children of a doubled folder repeat it.
    public static func normalizationDuplicates(in paths: [String]) -> [String] {
        var variants: [String: Set<[UInt32]>] = [:]
        var firstSeen: [String: String] = [:]
        for path in paths {
            let components = path.split(separator: "/").map(String.init)
            for level in components.indices {
                let prefix = components.prefix(level + 1).joined(separator: "/")
                let key = prefix.precomposedStringWithCanonicalMapping
                variants[key, default: []].insert(prefix.unicodeScalars.map(\.value))
                if firstSeen[key] == nil { firstSeen[key] = prefix }
            }
        }
        let doubled = Set(variants.filter { $0.value.count > 1 }.keys)
        return doubled.compactMap { key -> String? in
            let parent = key.split(separator: "/").dropLast().joined(separator: "/")
            if !parent.isEmpty, doubled.contains(parent) { return nil }
            return firstSeen[key]
        }.sorted()
    }

    /// The stderr rclone itself prints for such duplicates, so the snapshot path reuses the mapping above.
    public static func duplicateStderr(for names: [String]) -> String {
        names.map { "\($0): Duplicate directory found in destination - ignoring" }.joined(separator: "\n")
    }

    /// Names from every "<name>: Duplicate directory found…" line, joined for display.
    private static func duplicateFolderName(in stderr: String) -> String? {
        let marker = ": Duplicate directory found in destination"
        let names = stderr.split(whereSeparator: \.isNewline).compactMap { line -> String? in
            guard let range = line.range(of: marker) else { return nil }
            var name = String(line[..<range.lowerBound])
            if let prefix = name.range(of: #"^.*?\b(?:ERROR|NOTICE|WARNING|INFO)\s*:\s*"#, options: .regularExpression) {
                name.removeSubrange(prefix)
            }
            name = name.trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? nil : name
        }
        return names.isEmpty ? nil : names.joined(separator: ", ")
    }

    private static func isLocalPathFailure(stderr lowered: String, command: [String]) -> Bool {
        if lowered.contains("local file system") { return true }
        if lowered.contains("yandex") { return false }

        var positional: [String] = []
        var skipNext = false
        for argument in command {
            if skipNext { skipNext = false; continue }
            if valuedFlags.contains(argument) { skipNext = true; continue }
            if argument.hasPrefix("-") { continue }
            positional.append(argument)
        }
        // The first positional is the subcommand; "source root" errors point at the first path after it.
        let paths = Array(positional.dropFirst())
        let isRemote: (String) -> Bool = { path in
            guard let colon = path.firstIndex(of: ":") else { return false }
            return !path[..<colon].contains("/")
        }
        if lowered.contains("source root"), let source = paths.first { return !isRemote(source) }
        return !paths.isEmpty && !paths.contains(where: isRemote)
    }
}
