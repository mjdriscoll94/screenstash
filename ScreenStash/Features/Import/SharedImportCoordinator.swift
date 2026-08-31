import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class SharedImportCoordinator {
    private(set) var isImporting = false
    var notice: SharedImportNotice?

    func importPending(
        in context: ModelContext,
        dependencies: AppDependencies
    ) async {
        guard !isImporting else { return }
        isImporting = true
        defer { isImporting = false }

        do {
            let batch = try await dependencies.sharedImportQueue.pendingImports()
            guard !batch.imports.isEmpty || batch.invalidEntryCount > 0 else { return }

            let categories = try context.fetch(FetchDescriptor<ScreenshotCategoryRecord>())
            let categoriesByKey = Dictionary(uniqueKeysWithValues: categories.map { ($0.key, $0) })
            let existingIDs = Set(
                try context.fetch(FetchDescriptor<ScreenshotItem>()).map(\.id)
            )
            var importedCount = 0
            var failedCount = batch.invalidEntryCount

            for pending in batch.imports {
                if existingIDs.contains(pending.record.id) {
                    try await dependencies.sharedImportQueue.removeImport(id: pending.record.id)
                    continue
                }

                do {
                    let processed = try await dependencies.imageProcessor.process(pending.imageData)
                    let recognizedText = (try? await dependencies.textRecognizer.recognizeText(
                        in: processed.imageData
                    )) ?? ""
                    let category = pending.record.categoryKey.isEmpty
                        ? nil
                        : categoriesByKey[pending.record.categoryKey]
                    let title = pending.record.title?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let now = Date.now
                    let item = ScreenshotItem(
                        id: pending.record.id,
                        createdAt: pending.record.createdAt,
                        importedAt: now,
                        updatedAt: now,
                        imageData: processed.imageData,
                        thumbnailData: processed.thumbnailData,
                        recognizedText: recognizedText,
                        title: title,
                        category: category,
                        status: .inbox
                    )
                    context.insert(item)
                    do {
                        try context.save()
                    } catch {
                        context.delete(item)
                        throw error
                    }
                    // The item is already safely stored. If queue cleanup fails,
                    // the stable identifier prevents a duplicate on the next pass.
                    try? await dependencies.sharedImportQueue.removeImport(id: pending.record.id)
                    importedCount += 1
                } catch {
                    failedCount += 1
                }
            }

            if importedCount > 0 || failedCount > 0 {
                notice = SharedImportNotice(importedCount: importedCount, failedCount: failedCount)
            }
        } catch {
            notice = SharedImportNotice(
                importedCount: 0,
                failedCount: 1,
                detail: error.localizedDescription
            )
        }
    }
}

struct SharedImportNotice: Identifiable {
    let id = UUID()
    let importedCount: Int
    let failedCount: Int
    var detail: String?

    var title: String {
        failedCount == 0 ? "Added to FrameFile" : "Shared Import Finished"
    }

    var message: String {
        if let detail { return detail }
        if failedCount == 0 {
            return importedCount == 1
                ? "Your screenshot is ready in the Inbox."
                : "\(importedCount) screenshots are ready in the Inbox."
        }
        return "Imported \(importedCount). \(failedCount) could not be imported. FrameFile kept their staged data and will retry any recoverable items."
    }
}
