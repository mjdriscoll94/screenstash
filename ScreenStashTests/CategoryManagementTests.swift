import Foundation
import SwiftData
import XCTest
@testable import ScreenStash

@MainActor
final class CategoryManagementTests: XCTestCase {
    func testAddingCategoryTrimsNameAndAssignsCustomKey() throws {
        let container = try ScreenStashContainer.make(inMemory: true)
        let context = ModelContext(container)
        let builtIn = ScreenshotCategoryRecord(category: .other, sortOrder: 9)
        context.insert(builtIn)
        try context.save()

        let viewModel = CategoriesViewModel()
        let category = try viewModel.addCategory(
            name: "  Work Ideas  ",
            symbolName: "lightbulb",
            categories: [builtIn],
            context: context
        )

        XCTAssertEqual(category.name, "Work Ideas")
        XCTAssertEqual(category.symbolName, "lightbulb")
        XCTAssertEqual(category.sortOrder, 10)
        XCTAssertTrue(category.key.hasPrefix(ScreenshotCategoryRecord.customKeyPrefix))
        XCTAssertFalse(category.isBuiltIn)
    }

    func testDuplicateNamesAreRejectedCaseInsensitively() throws {
        let existing = ScreenshotCategoryRecord(
            customName: "Projects",
            symbolName: "folder",
            sortOrder: 10
        )
        let viewModel = CategoriesViewModel()

        XCTAssertThrowsError(
            try viewModel.validatedName("projects", categories: [existing])
        ) { error in
            XCTAssertEqual(error as? CategoryManagementError, .duplicateName)
        }
    }

    func testDeletingCustomCategoryMakesScreenshotsUnsorted() throws {
        let container = try ScreenStashContainer.make(inMemory: true)
        let context = ModelContext(container)
        let category = ScreenshotCategoryRecord(
            customName: "Projects",
            symbolName: "folder",
            sortOrder: 10
        )
        let item = ScreenshotItem(
            imageData: Data([1]),
            title: "Project plan",
            category: category
        )
        context.insert(category)
        context.insert(item)
        try context.save()

        let affectedCount = try CategoriesViewModel().deleteCategory(
            category,
            items: [item],
            context: context
        )

        XCTAssertEqual(affectedCount, 1)
        XCTAssertNil(item.category)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ScreenshotCategoryRecord>()).isEmpty)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ScreenshotItem>()).count, 1)
    }

    func testDeletingBuiltInCategoryMakesScreenshotsUnsorted() throws {
        let container = try ScreenStashContainer.make(inMemory: true)
        let context = ModelContext(container)
        let category = ScreenshotCategoryRecord(category: .travel, sortOrder: 0)
        let item = ScreenshotItem(
            imageData: Data([1]),
            title: "Flight details",
            category: category
        )
        context.insert(category)
        context.insert(item)
        try context.save()

        let affectedCount = try CategoriesViewModel().deleteCategory(
            category,
            items: [item],
            context: context
        )

        XCTAssertEqual(affectedCount, 1)
        XCTAssertNil(item.category)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ScreenshotCategoryRecord>()).isEmpty)
    }

    func testSeederDoesNotRestoreDeletedBuiltInCategory() async throws {
        let container = try ScreenStashContainer.make(inMemory: true)
        let context = ModelContext(container)

        await BuiltInCategorySeeder.seedIfNeeded(
            in: context,
            excluding: [ScreenshotCategory.travel.rawValue]
        )

        let categories = try context.fetch(FetchDescriptor<ScreenshotCategoryRecord>())
        XCTAssertEqual(categories.count, ScreenshotCategory.allCases.count - 1)
        XCTAssertFalse(categories.contains { $0.key == ScreenshotCategory.travel.rawValue })
    }

    func testResolvedCollectionContainsOnlyResolvedItemsInMostRecentOrder() {
        let olderResolved = ScreenshotItem(
            imageData: Data([1]),
            title: "Older",
            status: .resolved,
            resolvedAt: Date(timeIntervalSince1970: 100)
        )
        let newerResolved = ScreenshotItem(
            imageData: Data([2]),
            title: "Newer",
            status: .resolved,
            resolvedAt: Date(timeIntervalSince1970: 200)
        )
        let active = ScreenshotItem(
            imageData: Data([3]),
            title: "Active",
            status: .active
        )

        let results = CategoriesViewModel().resolvedItems(
            from: [olderResolved, active, newerResolved]
        )

        XCTAssertEqual(results.map(\.id), [newerResolved.id, olderResolved.id])
    }

    func testUnsortedCollectionContainsOnlyUnresolvedItemsWithoutCategory() {
        let category = ScreenshotCategoryRecord(category: .other, sortOrder: 0)
        let unsorted = ScreenshotItem(
            importedAt: Date(timeIntervalSince1970: 200),
            imageData: Data([1]),
            title: "Unsorted",
            status: .inbox
        )
        let categorized = ScreenshotItem(
            importedAt: Date(timeIntervalSince1970: 300),
            imageData: Data([2]),
            title: "Categorized",
            category: category,
            status: .active
        )
        let resolvedWithoutCategory = ScreenshotItem(
            importedAt: Date(timeIntervalSince1970: 400),
            imageData: Data([3]),
            title: "Resolved",
            status: .resolved
        )

        let results = CategoriesViewModel().unsortedItems(
            from: [categorized, resolvedWithoutCategory, unsorted]
        )

        XCTAssertEqual(results.map(\.id), [unsorted.id])
    }

    func testArchivedCollectionContainsOnlyArchivedItemsInMostRecentOrder() {
        let older = ScreenshotItem(
            updatedAt: Date(timeIntervalSince1970: 100),
            imageData: Data([1]),
            title: "Older",
            status: .archived
        )
        let newer = ScreenshotItem(
            updatedAt: Date(timeIntervalSince1970: 200),
            imageData: Data([2]),
            title: "Newer",
            status: .archived
        )
        let active = ScreenshotItem(imageData: Data([3]), status: .active)

        let results = CategoriesViewModel().archivedItems(from: [older, active, newer])

        XCTAssertEqual(results.map(\.id), [newer.id, older.id])
    }

    func testResetAllPreferencesClearsEveryScreenStashPreference() throws {
        let suiteName = "ScreenStashPreferencesTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        for key in AppPreferenceKey.allKeys {
            defaults.set("test-value", forKey: key)
        }

        AppPreferenceKey.resetAll(in: defaults)

        for key in AppPreferenceKey.allKeys {
            XCTAssertNil(defaults.object(forKey: key), "Expected \(key) to be removed")
        }
    }
}
