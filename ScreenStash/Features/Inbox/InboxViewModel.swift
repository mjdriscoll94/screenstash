import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class InboxViewModel {
    var filter: InboxFilter = .all
    var query = ""
    var isSelecting = false
    var selectedIDs: Set<UUID> = []
    var errorMessage: String?
    var showDeleteConfirmation = false

    func filteredItems(from items: [ScreenshotItem], now: Date = .now) -> [ScreenshotItem] {
        let unresolved = items.filter(\.isUnresolved)
        let filtered = unresolved.filter { item in
            switch filter {
            case .all:
                true
            case .unsorted:
                !item.isReviewed || item.category == nil
            case .reminders:
                item.reminderDate != nil
            case .favorites:
                item.isFavorite
            case .recentlyAdded:
                item.importedAt >= now.addingTimeInterval(-7 * 86_400)
            case .olderThanThirtyDays:
                item.createdAt < now.addingTimeInterval(-30 * 86_400)
            }
        }

        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return filtered }

        return filtered.filter { item in
            [item.title, item.notes, item.recognizedText, item.category?.name ?? ""]
                .contains { $0.localizedCaseInsensitiveContains(needle) }
        }
    }

    func toggleSelection(for item: ScreenshotItem) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }

    func beginSelecting() {
        isSelecting = true
    }

    func toggleAllSelections(in items: [ScreenshotItem]) {
        let itemIDs = Set(items.map(\.id))
        if !itemIDs.isEmpty && itemIDs.isSubset(of: selectedIDs) {
            selectedIDs.subtract(itemIDs)
        } else {
            selectedIDs.formUnion(itemIDs)
        }
    }

    func endSelecting() {
        isSelecting = false
        selectedIDs.removeAll()
    }

    func favoriteSelected(in items: [ScreenshotItem], context: ModelContext) {
        let selected = items.filter { selectedIDs.contains($0.id) }
        let shouldFavorite = selected.contains { !$0.isFavorite }
        selected.forEach {
            $0.isFavorite = shouldFavorite
            $0.updatedAt = .now
        }
        save(context)
    }

    func resolveSelected(
        in items: [ScreenshotItem],
        context: ModelContext,
        notifications: any NotificationScheduling
    ) async {
        for item in items where selectedIDs.contains(item.id) {
            await notifications.cancelReminder(for: item.id)
            item.markResolved()
        }
        save(context)
        endSelecting()
    }

    func archiveSelected(
        in items: [ScreenshotItem],
        context: ModelContext,
        notifications: any NotificationScheduling
    ) async {
        for item in items where selectedIDs.contains(item.id) {
            await notifications.cancelReminder(for: item.id)
            item.archive()
        }
        save(context)
        endSelecting()
    }

    func deleteSelected(
        in items: [ScreenshotItem],
        context: ModelContext,
        notifications: any NotificationScheduling
    ) async {
        for item in items where selectedIDs.contains(item.id) {
            await notifications.cancelReminder(for: item.id)
            context.delete(item)
        }
        save(context)
        endSelecting()
    }

    private func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
