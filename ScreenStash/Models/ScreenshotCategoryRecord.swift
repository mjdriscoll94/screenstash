import Foundation
import SwiftData

@Model
final class ScreenshotCategoryRecord {
    static let customKeyPrefix = "custom-"

    @Attribute(.unique) var key: String
    var name: String
    var symbolName: String
    var sortOrder: Int
    var isBuiltIn: Bool
    var createdAt: Date

    init(
        key: String,
        name: String,
        symbolName: String,
        sortOrder: Int,
        isBuiltIn: Bool = true,
        createdAt: Date = .now
    ) {
        self.key = key
        self.name = name
        self.symbolName = symbolName
        self.sortOrder = sortOrder
        self.isBuiltIn = isBuiltIn
        self.createdAt = createdAt
    }

    convenience init(category: ScreenshotCategory, sortOrder: Int) {
        self.init(
            key: category.rawValue,
            name: category.displayName,
            symbolName: category.symbolName,
            sortOrder: sortOrder
        )
    }

    convenience init(
        customName name: String,
        symbolName: String,
        sortOrder: Int,
        id: UUID = UUID(),
        createdAt: Date = .now
    ) {
        self.init(
            key: Self.customKeyPrefix + id.uuidString.lowercased(),
            name: name,
            symbolName: symbolName,
            sortOrder: sortOrder,
            isBuiltIn: false,
            createdAt: createdAt
        )
    }

    var builtInCategory: ScreenshotCategory? {
        ScreenshotCategory(rawValue: key)
    }
}
