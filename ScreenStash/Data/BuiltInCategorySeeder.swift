import Foundation
import SwiftData

@MainActor
enum BuiltInCategorySeeder {
    static func seedIfNeeded(
        in context: ModelContext,
        excluding deletedKeys: Set<String> = DeletedBuiltInCategoryStore.keys()
    ) async {
        let descriptor = FetchDescriptor<ScreenshotCategoryRecord>()
        guard let existingCategories = try? context.fetch(descriptor) else {
            return
        }

        let existingKeys = Set(existingCategories.map(\.key))
        var insertedCategory = false

        for (index, category) in ScreenshotCategory.allCases.enumerated()
            where !existingKeys.contains(category.rawValue)
                && !deletedKeys.contains(category.rawValue) {
            context.insert(ScreenshotCategoryRecord(category: category, sortOrder: index))
            insertedCategory = true
        }

        if insertedCategory {
            try? context.save()
        }
    }
}
