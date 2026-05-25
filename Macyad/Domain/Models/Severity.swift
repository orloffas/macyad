public enum Severity: String, Codable, Sendable, Comparable {
    case healthy
    case info
    case warning
    case alarm

    private var rank: Int {
        switch self {
        case .healthy:
            0
        case .info:
            1
        case .warning:
            2
        case .alarm:
            3
        }
    }

    public static func < (lhs: Severity, rhs: Severity) -> Bool {
        lhs.rank < rhs.rank
    }
}
