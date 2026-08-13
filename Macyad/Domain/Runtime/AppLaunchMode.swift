import Foundation

public enum AppLaunchMode: Sendable, Equatable {
    case normal
    case foreground
    case uiTestOnboardingMissingRclone
    case uiTestReadyState
    /// Ready state plus a few pairs on disk. The panes that show a list or a
    /// table behave differently once they have rows, and every other UI test
    /// runs against an empty state where those paths are never taken. The
    /// language is carried here because the same seeded state is what the
    /// README screenshots are taken from, in both languages.
    case uiTestSeededPairs(language: AppLanguage)

    public init(
        arguments: [String],
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        // Compare against dash-stripped arguments. A launch argument that is a
        // bare word (`UITEST_READY_STATE`) reads to AppKit as a file path to
        // open, so the app is launched with "open document" semantics and
        // SwiftUI never creates the default `WindowGroup` window — the app
        // comes up windowless and every XCUITest query finds nothing.
        // Callers must pass `-UITEST_READY_STATE`; the bare spelling stays
        // accepted so older invocations keep selecting the right mode.
        let flags = Set(arguments.map { $0.drop { $0 == "-" } }.map(String.init))

        if flags.contains("UITEST_ONBOARDING_MISSING_RCLONE") {
            self = .uiTestOnboardingMissingRclone
        } else if flags.contains("UITEST_SEEDED_PAIRS") {
            self = .uiTestSeededPairs(language: flags.contains("UITEST_LANG_RU") ? .russian : .english)
        } else if flags.contains("UITEST_READY_STATE") {
            self = .uiTestReadyState
        } else if Self.requestsForegroundLaunch(arguments: arguments, environment: environment) {
            self = .foreground
        } else {
            self = .normal
        }
    }

    /// Аргументы требуют показать окно независимо от того, как приложение
    /// запустили. Обычный запуск (`.normal`) сюда не входит: по одним только
    /// аргументам не отличить двойной клик от автозапуска на входе в систему.
    public var shouldForceForegroundWindow: Bool {
        switch self {
        case .normal:
            false
        case .foreground, .uiTestOnboardingMissingRclone, .uiTestReadyState, .uiTestSeededPairs:
            true
        }
    }

    /// Показывать ли окно и иконку в Dock на старте.
    ///
    /// Аргументы дают только принудительный foreground; отличить двойной клик
    /// от автозапуска login item'ом можно единственным измеренным признаком —
    /// активацией. Пользовательский запуск LaunchServices выводит приложение
    /// на передний план, автозапуск — нет.
    ///
    /// `NSApplication.launchIsDefaultUserInfoKey` для этой роли не годится:
    /// замерено 2026-08-13 на подписанной сборке — ключ приходит `false` и при
    /// `open -a`, и при `open -ga`.
    public func presentsWindowOnLaunch(isUserActivated: Bool) -> Bool {
        shouldForceForegroundWindow || isUserActivated
    }

    public var stubbedRcloneLocation: String? {
        switch self {
        case .normal, .foreground, .uiTestOnboardingMissingRclone:
            nil
        case .uiTestReadyState, .uiTestSeededPairs:
            "/opt/homebrew/bin/rclone"
        }
    }

    public var usesEphemeralPaths: Bool {
        switch self {
        case .normal, .foreground:
            false
        case .uiTestOnboardingMissingRclone, .uiTestReadyState, .uiTestSeededPairs:
            true
        }
    }

    /// The language the seeded state is written with, or nil when this mode
    /// seeds nothing.
    public var seededSampleLanguage: AppLanguage? {
        guard case let .uiTestSeededPairs(language) = self else {
            return nil
        }

        return language
    }

    private static func requestsForegroundLaunch(
        arguments: [String],
        environment: [String: String]
    ) -> Bool {
        arguments.contains("MACYAD_FORCE_FOREGROUND")
            || arguments.contains("--force-foreground")
            || arguments.contains { $0.hasPrefix("MACYAD_FORCE_FOREGROUND=") }
            || isEnabled(environment["MACYAD_FORCE_FOREGROUND"])
    }

    private static func isEnabled(_ value: String?) -> Bool {
        guard let normalizedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return false
        }

        return ["1", "true", "yes", "on"].contains(normalizedValue)
    }
}
