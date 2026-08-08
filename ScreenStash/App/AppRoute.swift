import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case inbox
    case categories
    case search
    case settings

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var symbolName: String {
        switch self {
        case .inbox: "tray"
        case .categories: "square.grid.2x2"
        case .search: "magnifyingglass"
        case .settings: "gearshape"
        }
    }
}

