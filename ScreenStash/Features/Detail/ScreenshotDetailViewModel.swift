import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class ScreenshotDetailViewModel {
    var isWorking = false
    var errorMessage: String?
    var reminderConfirmationMessage: String?
    var reminderDraft: Date

    init(item: ScreenshotItem) {
        let now = Date.now
        let suggestedDate = Calendar.current.date(byAdding: .day, value: 1, to: now)
            ?? now.addingTimeInterval(86_400)
        if let savedDate = item.reminderDate, savedDate > now {
            reminderDraft = savedDate
        } else {
            reminderDraft = suggestedDate
        }
    }

    func saveEdits(for item: ScreenshotItem, context: ModelContext) {
        item.updatedAt = .now
        do {
            try context.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveReminder(
        for item: ScreenshotItem,
        context: ModelContext,
        notifications: any NotificationScheduling
    ) async {
        isWorking = true
        defer { isWorking = false }

        do {
            let isUpdate = item.reminderDate != nil
            try await notifications.scheduleReminder(
                for: item.id,
                title: item.displayTitle,
                at: reminderDraft
            )
            item.reminderDate = reminderDraft
            item.updatedAt = .now
            try context.save()
            reminderConfirmationMessage = isUpdate ? "Reminder updated" : "Reminder saved"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeReminder(
        for item: ScreenshotItem,
        context: ModelContext,
        notifications: any NotificationScheduling
    ) async {
        isWorking = true
        defer { isWorking = false }

        await notifications.cancelReminder(for: item.id)
        item.reminderDate = nil
        item.updatedAt = .now

        do {
            try context.save()
            reminderConfirmationMessage = "Reminder removed"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resolve(
        _ item: ScreenshotItem,
        context: ModelContext,
        notifications: any NotificationScheduling
    ) async -> Bool {
        isWorking = true
        defer { isWorking = false }
        await notifications.cancelReminder(for: item.id)
        item.markResolved()
        return saveAction(context)
    }

    func archive(
        _ item: ScreenshotItem,
        context: ModelContext,
        notifications: any NotificationScheduling
    ) async -> Bool {
        isWorking = true
        defer { isWorking = false }
        await notifications.cancelReminder(for: item.id)
        item.archive()
        return saveAction(context)
    }

    func reopen(_ item: ScreenshotItem, context: ModelContext) -> Bool {
        item.markActive()
        return saveAction(context)
    }

    func delete(
        _ item: ScreenshotItem,
        context: ModelContext,
        notifications: any NotificationScheduling
    ) async -> Bool {
        isWorking = true
        defer { isWorking = false }
        await notifications.cancelReminder(for: item.id)
        context.delete(item)
        return saveAction(context)
    }

    private func saveAction(_ context: ModelContext) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
