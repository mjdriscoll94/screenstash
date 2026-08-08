import Foundation

enum ScreenshotStatus: String, CaseIterable, Codable, Identifiable, Sendable {
    case inbox
    case active
    case resolved
    case archived

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var symbolName: String {
        switch self {
        case .inbox: "tray"
        case .active: "circle.dashed"
        case .resolved: "checkmark.circle"
        case .archived: "archivebox"
        }
    }

    var isUnresolved: Bool {
        self == .inbox || self == .active
    }
}

