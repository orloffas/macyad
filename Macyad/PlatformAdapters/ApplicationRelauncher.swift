import AppKit
import Foundation

enum ApplicationRelauncher {
    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true

        NSWorkspace.shared.openApplication(
            at: Bundle.main.bundleURL,
            configuration: configuration
        ) { _, error in
            guard error == nil else {
                return
            }

            Task { @MainActor in
                NSApp.terminate(nil)
            }
        }
    }
}
