import Foundation
@preconcurrency import UserNotifications

protocol NotificationScheduling: Sendable {
    func authorizationStatus() async -> UNAuthorizationStatus
    func scheduleReminder(for itemID: UUID, title: String, at date: Date) async throws
    func cancelReminder(for itemID: UUID) async
    func cancelAllReminders() async
}

actor NotificationService: NotificationScheduling {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    static func identifier(for itemID: UUID) -> String {
        "screenstash.reminder.\(itemID.uuidString.lowercased())"
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func scheduleReminder(for itemID: UUID, title: String, at date: Date) async throws {
        guard date > .now else {
            throw ScreenStashServiceError.reminderDateInPast
        }

        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            guard granted else {
                throw ScreenStashServiceError.notificationPermissionDenied
            }
        case .denied:
            throw ScreenStashServiceError.notificationPermissionDenied
        case .authorized, .provisional, .ephemeral:
            break
        @unknown default:
            throw ScreenStashServiceError.notificationPermissionDenied
        }

        let content = UNMutableNotificationContent()
        content.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Screenshot reminder"
            : title
        content.body = "You saved this in ScreenStash."
        content.sound = .default
        content.userInfo = ["screenshotID": itemID.uuidString]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        let request = UNNotificationRequest(
            identifier: Self.identifier(for: itemID),
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )

        do {
            try await center.add(request)
        } catch {
            throw ScreenStashServiceError.notificationSchedulingFailed(error.localizedDescription)
        }
    }

    func cancelReminder(for itemID: UUID) async {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier(for: itemID)])
    }

    func cancelAllReminders() async {
        center.removeAllPendingNotificationRequests()
    }
}
