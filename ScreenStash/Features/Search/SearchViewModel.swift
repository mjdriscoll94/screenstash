import Foundation
import Observation

@Observable
@MainActor
final class SearchViewModel {
    var query = ""
    var categoryKey: String?
    var dateFilter: ImportedDateFilter = .anyTime
    var status: ScreenshotStatus?
    var favoritesOnly = false
    var reminderFilter: ReminderSearchFilter = .any
    var isFilterPresented = false

    var hasFilters: Bool {
        categoryKey != nil
            || dateFilter != .anyTime
            || status != nil
            || favoritesOnly
            || reminderFilter != .any
    }

    var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasFilters
    }

    func results(
        from items: [ScreenshotItem],
        now: Date = .now
    ) -> [ScreenshotItem] {
        items.filter { item in
            guard passesLibraryVisibility(item) else { return false }
            guard categoryKey == nil || item.category?.key == categoryKey else { return false }
            guard !favoritesOnly || item.isFavorite else { return false }
            guard passesDateFilter(item, now: now) else { return false }
            guard passesReminderFilter(item, now: now) else { return false }
            return matchReason(for: item) != nil
        }
    }

    func matchReason(for item: ScreenshotItem) -> SearchMatchReason? {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return .filters }

        if item.title.localizedCaseInsensitiveContains(needle) { return .title }
        if item.notes.localizedCaseInsensitiveContains(needle) { return .notes }
        if item.recognizedText.localizedCaseInsensitiveContains(needle) { return .recognizedText }
        if item.category?.name.localizedCaseInsensitiveContains(needle) == true { return .category }
        return nil
    }

    func resetFilters() {
        categoryKey = nil
        dateFilter = .anyTime
        status = nil
        favoritesOnly = false
        reminderFilter = .any
    }

    private func passesLibraryVisibility(_ item: ScreenshotItem) -> Bool {
        if let status {
            return item.status == status
        }
        return item.isUnresolved
    }

    private func passesDateFilter(_ item: ScreenshotItem, now: Date) -> Bool {
        switch dateFilter {
        case .anyTime:
            true
        case .lastSevenDays:
            item.importedAt >= now.addingTimeInterval(-7 * 86_400)
        case .lastThirtyDays:
            item.importedAt >= now.addingTimeInterval(-30 * 86_400)
        case .lastNinetyDays:
            item.importedAt >= now.addingTimeInterval(-90 * 86_400)
        case .olderThanNinetyDays:
            item.importedAt < now.addingTimeInterval(-90 * 86_400)
        }
    }

    private func passesReminderFilter(_ item: ScreenshotItem, now: Date) -> Bool {
        switch reminderFilter {
        case .any:
            true
        case .hasReminder:
            item.reminderDate != nil
        case .noReminder:
            item.reminderDate == nil
        case .overdue:
            item.reminderDate.map { $0 < now } ?? false
        }
    }
}
