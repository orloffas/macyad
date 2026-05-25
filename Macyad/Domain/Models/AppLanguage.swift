import Foundation

public enum AppLanguage: String, Codable, CaseIterable, Sendable {
    case english = "en"
    case russian = "ru"

    public init(code: String) {
        self = code == Self.russian.rawValue ? .russian : .english
    }
}

public enum AppLanguageState {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var currentLanguage: AppLanguage = .english

    public static var current: AppLanguage {
        lock.lock()
        defer { lock.unlock() }
        return currentLanguage
    }

    public static func update(_ language: AppLanguage) {
        lock.lock()
        currentLanguage = language
        lock.unlock()
    }
}
