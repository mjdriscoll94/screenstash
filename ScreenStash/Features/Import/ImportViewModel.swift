import Foundation
import Observation
import PhotosUI
import SwiftData
import SwiftUI

struct ImportIssue: Identifiable, Sendable {
    let id = UUID()
    let itemNumber: Int
    let message: String
}

@Observable
@MainActor
final class ImportViewModel {
    private(set) var isImporting = false
    private(set) var completedCount = 0
    private(set) var totalCount = 0
    private(set) var currentMessage = "Preparing screenshots…"
    private(set) var issues: [ImportIssue] = []
    var importedItems: [ScreenshotItem] = []
    var isReviewPresented = false
    var summaryMessage: String?

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    func importSelections(
        _ selections: [PhotosPickerItem],
        in context: ModelContext,
        dependencies: AppDependencies,
        defaultCategoryKey: String
    ) async {
        guard !selections.isEmpty, !isImporting else { return }

        isImporting = true
        completedCount = 0
        totalCount = selections.count
        issues = []
        importedItems = []
        summaryMessage = nil

        let categories = (try? context.fetch(FetchDescriptor<ScreenshotCategoryRecord>())) ?? []
        let categoriesByKey = Dictionary(uniqueKeysWithValues: categories.map { ($0.key, $0) })

        for (offset, selection) in selections.enumerated() {
            let itemNumber = offset + 1
            currentMessage = "Processing screenshot \(itemNumber) of \(totalCount)…"

            do {
                guard let originalData = try await selection.loadTransferable(type: Data.self) else {
                    throw ScreenStashServiceError.unreadableImage
                }

                let processed = try await dependencies.imageProcessor.process(originalData)
                let recognizedText: String

                do {
                    currentMessage = "Recognizing text in screenshot \(itemNumber)…"
                    recognizedText = try await dependencies.textRecognizer.recognizeText(
                        in: processed.imageData
                    )
                } catch {
                    recognizedText = ""
                    issues.append(ImportIssue(
                        itemNumber: itemNumber,
                        message: "Imported without recognized text: \(error.localizedDescription)"
                    ))
                }

                let suggestion = dependencies.categorySuggester.suggestCategory(for: recognizedText)
                let chosenKey = suggestion == .other ? defaultCategoryKey : suggestion.rawValue
                let now = Date.now
                let item = ScreenshotItem(
                    createdAt: now,
                    importedAt: now,
                    updatedAt: now,
                    imageData: processed.imageData,
                    thumbnailData: processed.thumbnailData,
                    recognizedText: recognizedText,
                    title: "",
                    category: categoriesByKey[chosenKey] ?? categoriesByKey[ScreenshotCategory.other.rawValue]
                )

                context.insert(item)
                try context.save()
                importedItems.append(item)
            } catch {
                issues.append(ImportIssue(
                    itemNumber: itemNumber,
                    message: error.localizedDescription
                ))
            }

            completedCount = itemNumber
        }

        isImporting = false

        if importedItems.isEmpty {
            summaryMessage = issues.first?.message ?? "No screenshots could be imported."
        } else {
            if !issues.isEmpty {
                summaryMessage = "Imported \(importedItems.count) of \(totalCount) screenshots. Some items need attention."
            }
            isReviewPresented = true
        }
    }

    func clearSummary() {
        summaryMessage = nil
    }

}
