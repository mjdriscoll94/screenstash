import Foundation
import XCTest
@testable import ScreenStash

@MainActor
final class ExportServiceTests: XCTestCase {
    func testExportContainsImageOCRAndCompleteMetadata() throws {
        let imageData = Data([0xFF, 0xD8, 0xFF, 0xD9])
        let category = ScreenshotCategoryRecord(category: .confirmation, sortOrder: 0)
        let reviewedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let itemID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000123"))
        let item = ScreenshotItem(
            id: itemID,
            createdAt: reviewedAt.addingTimeInterval(-86_400),
            importedAt: reviewedAt,
            updatedAt: reviewedAt,
            imageData: imageData,
            recognizedText: "Confirmation ABC-123",
            title: "Hotel",
            notes: "Late arrival",
            category: category,
            status: .active,
            isFavorite: true,
            isReviewed: true,
            lastReviewedAt: reviewedAt
        )

        let payload = try ExportService().makePayload(from: [item])
        let manifest = try JSONDecoder.screenStash.decode(
            ScreenStashExportManifest.self,
            from: payload.metadata
        )
        let record = try XCTUnwrap(manifest.screenshots.first)
        let imageName = "\(item.id.uuidString.lowercased()).jpg"
        let textName = "\(item.id.uuidString.lowercased()).txt"

        XCTAssertEqual(manifest.formatVersion, 1)
        XCTAssertEqual(record.title, "Hotel")
        XCTAssertEqual(record.notes, "Late arrival")
        XCTAssertEqual(record.categoryName, "Confirmation")
        XCTAssertEqual(record.status, ScreenshotStatus.active.rawValue)
        XCTAssertTrue(record.isFavorite)
        XCTAssertTrue(record.isReviewed)
        XCTAssertEqual(record.lastReviewedAt, reviewedAt)
        XCTAssertEqual(payload.images[imageName], imageData)
        XCTAssertEqual(
            payload.recognizedTextFiles[textName],
            Data("Confirmation ABC-123".utf8)
        )
    }
}

private extension JSONDecoder {
    static var screenStash: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
