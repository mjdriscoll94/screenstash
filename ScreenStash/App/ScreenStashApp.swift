import SwiftData
import SwiftUI

@main
struct ScreenStashApp: App {
    private let dependencies = AppDependencies.live
    private let containerResult: Result<ModelContainer, Error>

    init() {
        containerResult = Result { try ScreenStashContainer.make() }
    }

    var body: some Scene {
        WindowGroup {
            switch containerResult {
            case let .success(container):
                RootView()
                    .environment(\.appDependencies, dependencies)
                    .modelContainer(container)
            case let .failure(error):
                DatabaseUnavailableView(error: error)
            }
        }
    }
}

private struct DatabaseUnavailableView: View {
    let error: Error

    var body: some View {
        ContentUnavailableView {
            Label("FrameFile Couldn't Open", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("Your screenshots have not been changed. Close and reopen the app, then try again.")
        }
        .padding()
        .accessibilityHint(error.localizedDescription)
    }
}
