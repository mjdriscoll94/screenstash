import Foundation
import SwiftData

@Model
final class ScreenshotItem {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var importedAt: Date
    var updatedAt: Date
    @Attribute(.externalStorage) var imageData: Data
    @Attribute(.externalStorage) var thumbnailData: Data?
    var recognizedText: String
    var title: String
    var notes: String
    @Relationship(deleteRule: .nullify) var category: ScreenshotCategoryRecord?
    private var statusRawValue: String
    var reminderDate: Date?
    var isFavorite: Bool
    var resolvedAt: Date?
    var isReviewed: Bool
    var lastReviewedAt: Date?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        importedAt: Date = .now,
        updatedAt: Date = .now,
        imageData: Data,
        thumbnailData: Data? = nil,
        recognizedText: String = "",
        title: String = "",
        notes: String = "",
        category: ScreenshotCategoryRecord? = nil,
        status: ScreenshotStatus = .inbox,
        reminderDate: Date? = nil,
        isFavorite: Bool = false,
        resolvedAt: Date? = nil,
        isReviewed: Bool = false,
        lastReviewedAt: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.importedAt = importedAt
        self.updatedAt = updatedAt
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.recognizedText = recognizedText
        self.title = title
        self.notes = notes
        self.category = category
        self.statusRawValue = status.rawValue
        self.reminderDate = reminderDate
        self.isFavorite = isFavorite
        self.resolvedAt = resolvedAt
        self.isReviewed = isReviewed
        self.lastReviewedAt = lastReviewedAt
    }

    var status: ScreenshotStatus {
        get { ScreenshotStatus(rawValue: statusRawValue) ?? .inbox }
        set { statusRawValue = newValue.rawValue }
    }

    var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "Untitled Screenshot" : trimmedTitle
    }

    var isUnresolved: Bool {
        status.isUnresolved
    }

    func markActive(at date: Date = .now) {
        status = .active
        resolvedAt = nil
        updatedAt = date
    }

    func markResolved(at date: Date = .now) {
        status = .resolved
        resolvedAt = date
        reminderDate = nil
        updatedAt = date
    }

    func archive(at date: Date = .now) {
        status = .archived
        reminderDate = nil
        updatedAt = date
    }
}
