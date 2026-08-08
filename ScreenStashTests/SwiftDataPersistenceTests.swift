import Foundation
import SwiftData
import XCTest
@testable import ScreenStash

@MainActor
final class SwiftDataPersistenceTests: XCTestCase {
    func testScreenshotFieldsPersistInAnInMemoryContainer() throws {
        let container = try ScreenStashContainer.make(inMemory: true)
        let writer = ModelContext(container)
        let category = ScreenshotCategoryRecord(category: .travel, sortOrder: 0)
        let resolvedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let item = ScreenshotItem(
            imageData: Data([1, 2, 3]),
            thumbnailData: Data([1]),
            recognizedText: "Gate C12",
            title: "Flight",
            notes: "Pack passport",
            category: category,
            status: .resolved,
            isFavorite: true,
            resolvedAt: resolvedAt,
            isReviewed: true,
            lastReviewedAt: resolvedAt
        )
        let itemID = item.id
        writer.insert(category)
        writer.insert(item)
        try writer.save()

        let reader = ModelContext(container)
        let stored = try XCTUnwrap(
            reader.fetch(FetchDescriptor<ScreenshotItem>()).first { $0.id == itemID }
        )

        XCTAssertEqual(stored.status, .resolved)
        XCTAssertEqual(stored.category?.key, ScreenshotCategory.travel.rawValue)
        XCTAssertEqual(stored.recognizedText, "Gate C12")
        XCTAssertEqual(stored.notes, "Pack passport")
        XCTAssertTrue(stored.isFavorite)
        XCTAssertEqual(stored.resolvedAt, resolvedAt)
        XCTAssertEqual(stored.lastReviewedAt, resolvedAt)
    }
}
