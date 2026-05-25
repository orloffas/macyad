import ServiceManagement

protocol LoginItemControlling: Sendable {
    func setEnabled(_ enabled: Bool) throws
}

struct LoginItemService: LoginItemControlling {
    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            guard SMAppService.mainApp.status != .enabled else {
                return
            }

            try SMAppService.mainApp.register()
        } else {
            guard SMAppService.mainApp.status == .enabled else {
                return
            }

            try SMAppService.mainApp.unregister()
        }
    }
}
