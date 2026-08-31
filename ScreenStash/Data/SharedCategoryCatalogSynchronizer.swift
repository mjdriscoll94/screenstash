import SwiftData

@MainActor
enum SharedCategoryCatalogSynchronizer {
    static func sync(
        in context: ModelContext,
        catalog: any SharedCategoryCataloging
    ) async throws {
        let descriptor = FetchDescriptor<ScreenshotCategoryRecord>()
        let categories = [SharedCategoryOption.unsorted] + (try context.fetch(descriptor)
            .sorted { $0.sortOrder < $1.sortOrder }
            .map {
            SharedCategoryOption(
                key: $0.key,
                name: $0.name,
                symbolName: $0.symbolName,
                sortOrder: $0.sortOrder,
                isBuiltIn: $0.isBuiltIn
            )
            })
        try await catalog.saveCategories(categories)
    }
}
