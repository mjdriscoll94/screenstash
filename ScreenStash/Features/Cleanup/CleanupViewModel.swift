import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class CleanupViewModel {
    var errorMessage: String?
    var isWorking = false
    var showDeleteConfirmation = false
    var isReminderPresented = false
    var reminderDate = Calendar.current.date(byAdding: .day, value: 1, to: .now)
        ?? .now.addingTimeInterval(86_400)

    func candidates(
        from items: [ScreenshotItem],
        thresholdDays: Int,
        now: Date = .now
    ) -> [ScreenshotItem] {
        items
            .filter { AgingCalculator.needsReview(item: $0, thresholdDays: thresholdDays, now: now) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func keep(_ item: ScreenshotItem, context: ModelContext) {
        item.lastReviewedAt = .now
        item.updatedAt = .now
        save(context)
    }

    func resolve(
        _ item: ScreenshotItem,
        context: ModelContext,
        notifications: any NotificationScheduling
    ) async {
        await performNotificationRemovingAction(item, notifications: notifications) {
            item.markResolved()
        }
        save(context)
    }

    func archive(
        _ item: ScreenshotItem,
        context: ModelContext,
        notifications: any NotificationScheduling
    ) async {
        await performNotificationRemovingAction(item, notifications: notifications) {
            item.archive()
        }
        save(context)
    }

    func delete(
        _ item: ScreenshotItem,
        context: ModelContext,
        notifications: any NotificationScheduling
    ) async {
        isWorking = true
        await notifications.cancelReminder(for: item.id)
        context.delete(item)
        save(context)
        isWorking = false
    }

    func addReminder(
        to item: ScreenshotItem,
        context: ModelContext,
        notifications: any NotificationScheduling
    ) async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await notifications.scheduleReminder(
                for: item.id,
                title: item.displayTitle,
                at: reminderDate
            )
            item.reminderDate = reminderDate
            item.lastReviewedAt = .now
            item.updatedAt = .now
            try context.save()
            isReminderPresented = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func performNotificationRemovingAction(
        _ item: ScreenshotItem,
        notifications: any NotificationScheduling,
        action: () -> Void
    ) async {
        isWorking = true
        await notifications.cancelReminder(for: item.id)
        action()
        isWorking = false
    }

    private func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

