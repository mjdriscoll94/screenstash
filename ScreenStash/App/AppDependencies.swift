import SwiftUI

struct AppDependencies: Sendable {
    let imageProcessor: any ImageProcessing
    let textRecognizer: any TextRecognizing
    let categorySuggester: any CategorySuggesting
    let notificationScheduler: any NotificationScheduling
    let exportService: any DataExporting
    let sharedImportQueue: any SharedImportQueuing
    let sharedCategoryCatalog: any SharedCategoryCataloging

    static let live = AppDependencies(
        imageProcessor: ImageProcessingService(),
        textRecognizer: TextRecognitionService(),
        categorySuggester: CategorySuggestionService(),
        notificationScheduler: NotificationService(),
        exportService: ExportService(),
        sharedImportQueue: SharedImportQueue(),
        sharedCategoryCatalog: SharedCategoryCatalog()
    )
}

private struct AppDependenciesKey: EnvironmentKey {
    static let defaultValue = AppDependencies.live
}

extension EnvironmentValues {
    var appDependencies: AppDependencies {
        get { self[AppDependenciesKey.self] }
        set { self[AppDependenciesKey.self] = newValue }
    }
}
