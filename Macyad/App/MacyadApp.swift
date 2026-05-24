import SwiftUI

@main
struct MacyadApp: App {
    @State private var environment = try! AppEnvironment.bootstrap()

    var body: some Scene {
        WindowGroup("Macyad") {
            MainWindowView()
        }

        Settings {
            Text("Settings will land in Task 8.")
                .padding()
        }
    }
}
