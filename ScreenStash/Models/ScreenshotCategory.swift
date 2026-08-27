import Foundation

/// Stable identifiers for the categories bundled with FrameFile.
///
/// Screenshot items relate to `ScreenshotCategoryRecord` rather than persisting
/// this enum directly. That lets a later release add user-created categories
/// without changing the screenshot schema.
enum ScreenshotCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case buyLater = "buy-later"
    case readLater = "read-later"
    case event
    case address
    case recipe
    case confirmation
    case travel
    case quote
    case followUp = "follow-up"
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .buyLater: "Buy Later"
        case .readLater: "Read Later"
        case .event: "Event"
        case .address: "Address"
        case .recipe: "Recipe"
        case .confirmation: "Confirmation"
        case .travel: "Travel"
        case .quote: "Quote"
        case .followUp: "Follow Up"
        case .other: "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .buyLater: "cart"
        case .readLater: "book.closed"
        case .event: "calendar"
        case .address: "mappin.and.ellipse"
        case .recipe: "fork.knife"
        case .confirmation: "checkmark.seal"
        case .travel: "airplane"
        case .quote: "quote.opening"
        case .followUp: "arrowshape.turn.up.right"
        case .other: "tray"
        }
    }
}
