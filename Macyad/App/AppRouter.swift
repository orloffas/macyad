import Foundation

enum AppRoute: String, CaseIterable, Hashable {
    case onboarding
    case overview

    var title: String {
        switch self {
        case .onboarding:
            "Подключение"
        case .overview:
            "Обзор"
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
