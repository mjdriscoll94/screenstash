import Foundation
import XCTest
@testable import ScreenStash

final class SharedImportQueueTests: XCTestCase {
    func testEnqueueReadAndRemoveRoundTrip() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let queue = SharedImportQueue(baseDirectory: directory)
        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

        try await queue.enqueue(
            imageData: Data([1, 2, 3]),
            categoryKey: ScreenshotCategory.recipe.rawValue,
            title: "Dinner receipt",
            id: id,
            createdAt: createdAt
        )
        let batch = try await queue.pendingImports()
        let pending = try XCTUnwrap(batch.imports.first)

        XCTAssertEqual(batch.imports.count, 1)
        XCTAssertEqual(batch.invalidEntryCount, 0)
        XCTAssertEqual(pending.record.id, id)
        XCTAssertEqual(pending.record.categoryKey, ScreenshotCategory.recipe.rawValue)
        XCTAssertEqual(pending.record.title, "Dinner receipt")
        XCTAssertEqual(pending.record.createdAt, createdAt)
        XCTAssertEqual(pending.imageData, Data([1, 2, 3]))

        try await queue.removeImport(id: id)
        let remaining = try await queue.pendingImports()
        XCTAssertTrue(remaining.imports.isEmpty)
    }

    func testRetryWithSameIdentifierDoesNotDuplicateImport() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let queue = SharedImportQueue(baseDirectory: directory)
        let id = UUID()

        try await queue.enqueue(
            imageData: Data([1]),
            categoryKey: ScreenshotCategory.travel.rawValue,
            title: "Flight details",
            id: id,
            createdAt: .now
        )
        try await queue.enqueue(
            imageData: Data([1]),
            categoryKey: ScreenshotCategory.travel.rawValue,
            title: "Flight details",
            id: id,
            createdAt: .now
        )

        let batch = try await queue.pendingImports()
        XCTAssertEqual(batch.imports.count, 1)
    }

    func testEmptyImageIsRejected() async {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let queue = SharedImportQueue(baseDirectory: directory)

        do {
            try await queue.enqueue(
                imageData: Data(),
                categoryKey: ScreenshotCategory.other.rawValue,
                title: "Empty image",
                id: UUID(),
                createdAt: .now
            )
            XCTFail("Expected empty image data to fail")
        } catch let error as SharedImportQueueError {
            XCTAssertEqual(error, .emptyImage)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testPendingImportFromEarlierVersionWithoutTitleStillDecodes() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let id = UUID()
        let importDirectory = directory
            .appendingPathComponent(ScreenStashAppGroup.pendingDirectoryName, isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: importDirectory,
            withIntermediateDirectories: true
        )

        let metadata = try XCTUnwrap(
            """
            {
              "id": "\(id.uuidString)",
              "createdAt": "2023-11-14T22:13:20Z",
              "categoryKey": "other"
            }
            """.data(using: .utf8)
        )
        try metadata.write(to: importDirectory.appendingPathComponent("metadata.json"))
        try Data([9]).write(to: importDirectory.appendingPathComponent("image.data"))

        let batch = try await SharedImportQueue(baseDirectory: directory).pendingImports()
        let pending = try XCTUnwrap(batch.imports.first)

        XCTAssertEqual(batch.invalidEntryCount, 0)
        XCTAssertEqual(pending.record.id, id)
        XCTAssertNil(pending.record.title)
    }

    func testInvalidEntryIsQuarantinedInsteadOfAlertingOnEveryRead() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let invalidDirectory = directory
            .appendingPathComponent(ScreenStashAppGroup.pendingDirectoryName, isDirectory: true)
            .appendingPathComponent("invalid-entry", isDirectory: true)
        try FileManager.default.createDirectory(
            at: invalidDirectory,
            withIntermediateDirectories: true
        )
        try Data("not-json".utf8).write(
            to: invalidDirectory.appendingPathComponent("metadata.json")
        )

        let queue = SharedImportQueue(baseDirectory: directory)
        let firstRead = try await queue.pendingImports()
        let secondRead = try await queue.pendingImports()

        XCTAssertEqual(firstRead.invalidEntryCount, 1)
        XCTAssertEqual(secondRead.invalidEntryCount, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: invalidDirectory.path))

        let failedDirectory = directory.appendingPathComponent(
            ScreenStashAppGroup.failedDirectoryName,
            isDirectory: true
        )
        let quarantinedEntries = try FileManager.default.contentsOfDirectory(
            at: failedDirectory,
            includingPropertiesForKeys: nil
        )
        XCTAssertEqual(quarantinedEntries.count, 1)
    }

    func testRemoveAllImportsClearsPendingAndQuarantinedData() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let queue = SharedImportQueue(baseDirectory: directory)

        try await queue.enqueue(
            imageData: Data([1]),
            categoryKey: ScreenshotCategory.other.rawValue,
            title: "Pending",
            id: UUID(),
            createdAt: .now
        )

        let failedDirectory = directory.appendingPathComponent(
            ScreenStashAppGroup.failedDirectoryName,
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: failedDirectory,
            withIntermediateDirectories: true
        )
        try Data([2]).write(to: failedDirectory.appendingPathComponent("quarantined.data"))

        try await queue.removeAllImports()

        XCTAssertFalse(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent(
                ScreenStashAppGroup.pendingDirectoryName,
                isDirectory: true
            ).path
        ))
        XCTAssertFalse(FileManager.default.fileExists(atPath: failedDirectory.path))
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenStashQueueTests-\(UUID().uuidString)", isDirectory: true)
    }
}
