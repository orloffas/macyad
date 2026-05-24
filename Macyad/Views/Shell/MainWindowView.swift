import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var environment: AppEnvironment

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
