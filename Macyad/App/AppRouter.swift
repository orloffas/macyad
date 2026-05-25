import Foundation
import MacyadCore

enum AppRoute: String, CaseIterable, Hashable {
    case onboarding
    case overview

    func title(using copy: AppCopy) -> String {
        switch self {
        case .onboarding:
            copy.onboardingTitle
        case .overview:
            copy.overviewTitle
        }
    }

    var systemImage: String {
        switch self {
        case .onboarding:
            "checklist"
        case .overview:
            "square.grid.2x2"
        }
    }
}

enum SidebarSelection: Hashable {
    case route(AppRoute)
    case pair(UUID)
}
