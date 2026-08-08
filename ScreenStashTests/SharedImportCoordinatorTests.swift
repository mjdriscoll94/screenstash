import Foundation
import SwiftData
import XCTest
@testable import ScreenStash

@MainActor
final class SharedImportCoordinatorTests: XCTestCase {
    func testPendingShareImportsIntoChosenCategory() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenStashCoordinatorTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let queue = SharedImportQueue(baseDirectory: directory)
        let itemID = UUID()
        try await queue.enqueue(
            imageData: Data([1, 2, 3]),
            categoryKey: ScreenshotCategory.recipe.rawValue,
            title: "Dinner receipt",
            id: itemID,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let container = try ScreenStashContainer.make(inMemory: true)
        let context = ModelContext(container)
        context.insert(ScreenshotCategoryRecord(category: .recipe, sortOrder: 0))
        context.insert(ScreenshotCategoryRecord(category: .other, sortOrder: 1))
        try context.save()

        let dependencies = AppDependencies(
            imageProcessor: SharedImportImageProcessor(),
            textRecognizer: SharedImportTextRecognizer(),
            categorySuggester: CategorySuggestionService(),
            notificationScheduler: NotificationService(),
            exportService: ExportService(),
            sharedImportQueue: queue,
            sharedCategoryCatalog: SharedCategoryCatalog(baseDirectory: directory)
        )
        let coordinator = SharedImportCoordinator()

        await coordinator.importPending(in: context, dependencies: dependencies)

        let item = try XCTUnwrap(
            context.fetch(FetchDescriptor<ScreenshotItem>()).first { $0.id == itemID }
        )
        XCTAssertEqual(item.title, "Dinner receipt")
        XCTAssertEqual(item.recognizedText, "Shared screenshot title\nMore text")
        XCTAssertEqual(item.category?.key, ScreenshotCategory.recipe.rawValue)
        XCTAssertEqual(item.status, .inbox)
        let remaining = try await queue.pendingImports()
        XCTAssertTrue(remaining.imports.isEmpty)
        XCTAssertEqual(coordinator.notice?.importedCount, 1)
        XCTAssertEqual(coordinator.notice?.failedCount, 0)
    }
}

private struct SharedImportImageProcessor: ImageProcessing {
    func process(_ sourceData: Data) async throws -> ProcessedScreenshot {
        ProcessedScreenshot(
            imageData: sourceData,
            thumbnailData: sourceData,
            pixelWidth: 100,
            pixelHeight: 200
        )
    }
}

private struct SharedImportTextRecognizer: TextRecognizing {
    func recognizeText(in imageData: Data) async throws -> String {
        "Shared screenshot title\nMore text"
    }
}
