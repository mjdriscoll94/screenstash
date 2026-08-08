import Foundation

enum ImportedDateFilter: String, CaseIterable, Identifiable {
    case anyTime
    case lastSevenDays
    case lastThirtyDays
    case lastNinetyDays
    case olderThanNinetyDays

    var id: String { rawValue }

    var title: String {
        switch self {
        case .anyTime: "Any Time"
        case .lastSevenDays: "Last 7 Days"
        case .lastThirtyDays: "Last 30 Days"
        case .lastNinetyDays: "Last 90 Days"
        case .olderThanNinetyDays: "Older Than 90 Days"
        }
    }
}

enum ReminderSearchFilter: String, CaseIterable, Identifiable {
    case any
    case hasReminder
    case noReminder
    case overdue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .any: "Any"
        case .hasReminder: "Has Reminder"
        case .noReminder: "No Reminder"
        case .overdue: "Overdue"
        }
    }
}

enum SearchMatchReason: String {
    case title = "Title"
    case recognizedText = "Recognized text"
    case notes = "Notes"
    case category = "Category"
    case filters = "Matches filters"
}

