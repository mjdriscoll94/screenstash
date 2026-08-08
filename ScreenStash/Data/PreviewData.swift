import SwiftData

@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        do {
            return try ScreenStashContainer.make(inMemory: true)
        } catch {
            preconditionFailure("Unable to create preview container: \(error.localizedDescription)")
        }
    }()
}

