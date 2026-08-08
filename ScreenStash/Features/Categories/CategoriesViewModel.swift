import Foundation
import Observation
import SwiftData

enum CategoryManagementError: LocalizedError, Equatable {
    case emptyName
    case duplicateName

    var errorDescription: String? {
        switch self {
        case .emptyName:
            "Enter a category name."
        case .duplicateName:
            "A category with that name already exists."
        }
    }
}

@Observable
@MainActor
final class CategoriesViewModel {
    func activeItems(
        for category: ScreenshotCategoryRecord,
        from items: [ScreenshotItem]
    ) -> [ScreenshotItem] {
        items
            .filter { $0.category?.key == category.key && $0.isUnresolved }
            .sorted { $0.importedAt > $1.importedAt }
    }

    func recentItems(
        for category: ScreenshotCategoryRecord,
        from items: [ScreenshotItem],
        limit: Int = 3
    ) -> [ScreenshotItem] {
        Array(activeItems(for: category, from: items).prefix(limit))
    }

    func resolvedItems(from items: [ScreenshotItem]) -> [ScreenshotItem] {
        items
            .filter { $0.status == .resolved }
            .sorted {
                ($0.resolvedAt ?? $0.updatedAt) > ($1.resolvedAt ?? $1.updatedAt)
            }
    }

    @discardableResult
    func addCategory(
        name: String,
        symbolName: String,
        categories: [ScreenshotCategoryRecord],
        context: ModelContext
    ) throws -> ScreenshotCategoryRecord {
        let normalizedName = try validatedName(name, categories: categories)
        let nextSortOrder = (categories.map(\.sortOrder).max() ?? -1) + 1
        let category = ScreenshotCategoryRecord(
            customName: normalizedName,
            symbolName: symbolName,
            sortOrder: nextSortOrder
        )
        context.insert(category)

        do {
            try context.save()
            return category
        } catch {
            context.rollback()
            throw error
        }
    }

    func updateCategory(
        _ category: ScreenshotCategoryRecord,
        name: String,
        symbolName: String,
        categories: [ScreenshotCategoryRecord],
        context: ModelContext
    ) throws {
        let normalizedName = try validatedName(
            name,
            excludingKey: category.key,
            categories: categories
        )
        category.name = normalizedName
        category.symbolName = symbolName

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    /// Deletes a category while preserving its screenshots as Unsorted.
    @discardableResult
    func deleteCategory(
        _ category: ScreenshotCategoryRecord,
        items: [ScreenshotItem],
        context: ModelContext
    ) throws -> Int {
        let affectedItems = items.filter { $0.category?.key == category.key }
        affectedItems.forEach {
            $0.category = nil
            $0.updatedAt = .now
        }
        context.delete(category)

        do {
            try context.save()
            return affectedItems.count
        } catch {
            context.rollback()
            throw error
        }
    }

    func validatedName(
        _ name: String,
        excludingKey: String? = nil,
        categories: [ScreenshotCategoryRecord]
    ) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CategoryManagementError.emptyName }

        let isDuplicate = categories.contains {
            $0.key != excludingKey
                && $0.name.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        guard !isDuplicate else { throw CategoryManagementError.duplicateName }
        return trimmed
    }
}
