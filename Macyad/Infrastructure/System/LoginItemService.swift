import ServiceManagement

protocol LoginItemControlling: Sendable {
    func setEnabled(_ enabled: Bool) throws
}

struct LoginItemService: LoginItemControlling {
    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
