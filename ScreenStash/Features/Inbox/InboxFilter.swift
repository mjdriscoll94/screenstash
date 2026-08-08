import Foundation

enum InboxFilter: String, CaseIterable, Identifiable {
    case all
    case unsorted
    case reminders
    case favorites
    case recentlyAdded
    case olderThanThirtyDays

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .unsorted: "Unsorted"
        case .reminders: "Reminders"
        case .favorites: "Favorites"
        case .recentlyAdded: "Recently Added"
        case .olderThanThirtyDays: "Older Than 30 Days"
        }
    }

    var symbolName: String {
        switch self {
        case .all: "tray.full"
        case .unsorted: "questionmark.folder"
        case .reminders: "bell"
        case .favorites: "star"
        case .recentlyAdded: "clock"
        case .olderThanThirtyDays: "calendar.badge.exclamationmark"
        }
    }
}

