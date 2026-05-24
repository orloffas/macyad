import SwiftUI

struct MainWindowView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        NavigationSplitView {
            List {
                Label("Overview", systemImage: "square.grid.2x2")
            }
            .listStyle(.sidebar)
        } detail: {
            ContentUnavailableView(
                "Macyad",
                systemImage: "externaldrive.badge.icloud",
                description: Text(environment.paths.workspaceRoot.path)
            )
        }
    }
}
