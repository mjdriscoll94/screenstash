import Foundation
import Observation
@preconcurrency import UIKit
import UniformTypeIdentifiers

struct ShareableScreenshot: Identifiable, Sendable {
    let id: UUID
    let data: Data
    var title: String
}

enum ShareImportPhase: Equatable {
    case loading
    case ready
    case saving
    case failed(String)
}

@Observable
@MainActor
final class ShareImportViewModel {
    private let extensionContext: NSExtensionContext?
    private let queue: any SharedImportQueuing
    private let categoryCatalog: any SharedCategoryCataloging
    private var hasLoaded = false

    var phase: ShareImportPhase = .loading
    var screenshots: [ShareableScreenshot] = []
    var categories = SharedCategoryOption.builtInDefaults
    var selectedCategoryKey = ScreenshotCategory.other.rawValue

    var canSave: Bool {
        !screenshots.isEmpty && screenshots.allSatisfy {
            !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    init(
        extensionContext: NSExtensionContext?,
        queue: any SharedImportQueuing = SharedImportQueue(),
        categoryCatalog: any SharedCategoryCataloging = SharedCategoryCatalog()
    ) {
        self.extensionContext = extensionContext
        self.queue = queue
        self.categoryCatalog = categoryCatalog
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        phase = .loading

        if let sharedCategories = try? await categoryCatalog.loadCategories() {
            categories = sharedCategories.isEmpty ? [.unsorted] : sharedCategories
            if !categories.contains(where: { $0.key == selectedCategoryKey }) {
                selectedCategoryKey = categories.first?.key ?? ""
            }
        }

        let providers = extensionContext?.inputItems
            .compactMap { $0 as? NSExtensionItem }
            .flatMap { $0.attachments ?? [] }
            .filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) } ?? []

        guard !providers.isEmpty else {
            phase = .failed("Choose one or more screenshots to share with FrameFile.")
            return
        }

        var loaded: [ShareableScreenshot] = []
        for provider in providers {
            do {
                let data = try await loadImageData(from: provider)
                guard !data.isEmpty else { continue }
                loaded.append(ShareableScreenshot(id: UUID(), data: data, title: ""))
            } catch {
                continue
            }
        }

        screenshots = loaded
        phase = loaded.isEmpty
            ? .failed("FrameFile couldn't read the selected screenshot.")
            : .ready
    }

    func save() async {
        guard canSave else { return }
        phase = .saving

        do {
            for screenshot in screenshots {
                try await queue.enqueue(
                    imageData: screenshot.data,
                    categoryKey: selectedCategoryKey,
                    title: screenshot.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    id: screenshot.id,
                    createdAt: .now
                )
            }
            extensionContext?.completeRequest(returningItems: nil)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func cancel() {
        extensionContext?.cancelRequest(withError: CocoaError(.userCancelled))
    }

    private func loadImageData(from provider: NSItemProvider) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(
                forTypeIdentifier: UTType.image.identifier
            ) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data else {
                    continuation.resume(throwing: CocoaError(.fileReadUnknown))
                    return
                }
                continuation.resume(returning: data)
            }
        }
    }
}
