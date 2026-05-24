import SwiftUI

@main
struct MacyadApp: App {
    @State private var environment = MacyadApp.bootstrapEnvironment()

    var body: some Scene {
        WindowGroup("Macyad") {
            MainWindowView()
                .environment(environment)
        }

        Settings {
            Text("Settings will land in Task 8.")
                .padding()
        }
    }

    private static func bootstrapEnvironment() -> AppEnvironment {
        do {
            return try AppEnvironment.bootstrap()
        } catch {
            fatalError("Failed to bootstrap AppEnvironment: \(error)")
        }
    }
}
