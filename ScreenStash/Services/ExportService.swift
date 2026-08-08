import Foundation

struct ScreenshotExportRecord: Codable, Sendable {
    let id: UUID
    let createdAt: Date
    let importedAt: Date
    let updatedAt: Date
    let title: String
    let notes: String
    let recognizedText: String
    let categoryKey: String?
    let categoryName: String?
    let status: String
    let reminderDate: Date?
    let isFavorite: Bool
    let resolvedAt: Date?
    let isReviewed: Bool
    let lastReviewedAt: Date?
    let imageFilename: String
    let ocrFilename: String
}

struct ScreenStashExportManifest: Codable, Sendable {
    let formatVersion: Int
    let exportedAt: Date
    let application: String
    let screenshots: [ScreenshotExportRecord]
}

struct ScreenStashExportPayload: Sendable {
    let metadata: Data
    let images: [String: Data]
    let recognizedTextFiles: [String: Data]
}

protocol DataExporting: Sendable {
    func makePayload(from items: [ScreenshotItem]) throws -> ScreenStashExportPayload
}

struct ExportService: DataExporting {
    func makePayload(from items: [ScreenshotItem]) throws -> ScreenStashExportPayload {
        var images: [String: Data] = [:]
        var textFiles: [String: Data] = [:]

        let records = items
            .sorted { $0.importedAt < $1.importedAt }
            .map { item in
                let baseName = item.id.uuidString.lowercased()
                let imageFilename = "\(baseName).jpg"
                let textFilename = "\(baseName).txt"
                images[imageFilename] = item.imageData
                textFiles[textFilename] = item.recognizedText.data(using: .utf8) ?? Data()

                return ScreenshotExportRecord(
                    id: item.id,
                    createdAt: item.createdAt,
                    importedAt: item.importedAt,
                    updatedAt: item.updatedAt,
                    title: item.title,
                    notes: item.notes,
                    recognizedText: item.recognizedText,
                    categoryKey: item.category?.key,
                    categoryName: item.category?.name,
                    status: item.status.rawValue,
                    reminderDate: item.reminderDate,
                    isFavorite: item.isFavorite,
                    resolvedAt: item.resolvedAt,
                    isReviewed: item.isReviewed,
                    lastReviewedAt: item.lastReviewedAt,
                    imageFilename: "images/\(imageFilename)",
                    ocrFilename: "ocr/\(textFilename)"
                )
            }

        let manifest = ScreenStashExportManifest(
            formatVersion: 1,
            exportedAt: .now,
            application: "ScreenStash",
            screenshots: records
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601

        return ScreenStashExportPayload(
            metadata: try encoder.encode(manifest),
            images: images,
            recognizedTextFiles: textFiles
        )
    }
}
