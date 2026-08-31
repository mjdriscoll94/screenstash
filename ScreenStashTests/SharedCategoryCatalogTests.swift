import Foundation
import XCTest
@testable import ScreenStash

final class SharedCategoryCatalogTests: XCTestCase {
    func testCatalogRoundTripPreservesCustomCategoriesAndSortOrder() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenStashCategoryCatalogTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let catalog = SharedCategoryCatalog(baseDirectory: directory)
        let categories = [
            SharedCategoryOption(
                key: "custom-projects",
                name: "Projects",
                symbolName: "folder",
                sortOrder: 11,
                isBuiltIn: false
            ),
            SharedCategoryOption(
                key: ScreenshotCategory.other.rawValue,
                name: "Other",
                symbolName: "tray",
                sortOrder: 9,
                isBuiltIn: true
            )
        ]

        try await catalog.saveCategories(categories)
        let loaded = try await catalog.loadCategories()

        XCTAssertEqual(loaded.map(\.key), [ScreenshotCategory.other.rawValue, "custom-projects"])
        XCTAssertEqual(loaded.last?.name, "Projects")
        XCTAssertEqual(loaded.last?.isBuiltIn, false)
    }

    func testMissingCatalogFallsBackToUnsortedAndBuiltInCategories() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenStashMissingCategoryCatalogTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let catalog = SharedCategoryCatalog(baseDirectory: directory)

        let loaded = try await catalog.loadCategories()

        XCTAssertEqual(loaded.count, ScreenshotCategory.allCases.count + 1)
        XCTAssertEqual(loaded.first?.key, SharedCategoryOption.unsorted.key)
        XCTAssertEqual(loaded.dropFirst().first?.key, ScreenshotCategory.buyLater.rawValue)
    }
}
