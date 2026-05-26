import Foundation
import UserNotifications

public protocol UserNotificationControlling: UserNotificationSending {
    func authorizationStatus() async -> NotificationAuthorizationStatus
    func requestAuthorization() async throws -> NotificationAuthorizationStatus
    func sendTestNotification() async throws
}

public struct UserNotificationClient: UserNotificationControlling, Sendable {
    private let statusProvider: @Sendable () async -> NotificationAuthorizationStatus
    private let authorizationRequester: @Sendable () async throws -> NotificationAuthorizationStatus
    private let sender: @Sendable (String, String) async throws -> Void

    public init() {
        self.init(
            statusProvider: { await UserNotificationClient.liveStatusProvider() },
            authorizationRequester: { try await UserNotificationClient.liveAuthorizationRequester() },
            sender: { title, body in try await UserNotificationClient.liveSender(title: title, body: body) }
        )
    }

    public init(
        statusProvider: @escaping @Sendable () async -> NotificationAuthorizationStatus,
        authorizationRequester: @escaping @Sendable () async throws -> NotificationAuthorizationStatus,
        sender: @escaping @Sendable (String, String) async throws -> Void
    ) {
        self.statusProvider = statusProvider
        self.authorizationRequester = authorizationRequester
        self.sender = sender
    }

    public func authorizationStatus() async -> NotificationAuthorizationStatus {
        await statusProvider()
    }

    public func requestAuthorization() async throws -> NotificationAuthorizationStatus {
        try await authorizationRequester()
    }

    public func send(title: String, body: String) async throws {
        try await sender(title, body)
    }

    public func sendTestNotification() async throws {
        let copy = AppCopy.current
        try await send(title: copy.notificationsTestTitle, body: copy.notificationsTestBody)
    }

    static func liveStatusProvider() async -> NotificationAuthorizationStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: map(settings.authorizationStatus))
            }
        }
    }

    static func liveAuthorizationRequester() async throws -> NotificationAuthorizationStatus {
        _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        return await liveStatusProvider()
    }

    static func liveSender(title: String, body: String) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try await UNUserNotificationCenter.current().add(request)
    }

    private static func map(_ status: UNAuthorizationStatus) -> NotificationAuthorizationStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        case .provisional:
            return .provisional
        case .ephemeral:
            return .ephemeral
        @unknown default:
            return .unknown
        }
    }
}
