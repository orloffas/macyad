import SwiftUI

struct MainWindowView: View {
    var body: some View {
        NavigationSplitView {
            List {
                Label("Overview", systemImage: "square.grid.2x2")
            }
            .listStyle(.sidebar)
        } detail: {
            ContentUnavailableView("Macyad", systemImage: "externaldrive.badge.icloud")
        }
    }
}
