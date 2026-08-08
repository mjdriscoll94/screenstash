import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppPreferenceKey.hasSeenOnboarding)
    private var hasSeenOnboarding = false
    @State private var sharedImportCoordinator = SharedImportCoordinator()
    @State private var isPreparingApp = true

    private var skipsOnboardingForTesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-skip-onboarding")
    }

    private var forcesOnboardingForTesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-show-onboarding")
    }

    var body: some View {
        Group {
            if isPreparingApp {
                StartupLoadingView()
            } else if !forcesOnboardingForTesting && (hasSeenOnboarding || skipsOnboardingForTesting) {
                MainTabView()
            } else {
                OnboardingView {
                    hasSeenOnboarding = true
                }
            }
        }
        .task {
            guard isPreparingApp else { return }

            await BuiltInCategorySeeder.seedIfNeeded(in: modelContext)
            try? await SharedCategoryCatalogSynchronizer.sync(
                in: modelContext,
                catalog: dependencies.sharedCategoryCatalog
            )
            DevelopmentSampleData.seedIfRequested(in: modelContext)
            await sharedImportCoordinator.importPending(
                in: modelContext,
                dependencies: dependencies
            )

            withAnimation(.easeOut(duration: 0.2)) {
                isPreparingApp = false
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await sharedImportCoordinator.importPending(
                    in: modelContext,
                    dependencies: dependencies
                )
            }
        }
        .alert(item: $sharedImportCoordinator.notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

private struct StartupLoadingView: View {
    var body: some View {
        ZStack {
            Color("LaunchBackground")
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
                    .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text("ScreenStash")
                        .font(.title2.weight(.semibold))

                    ProgressView("Preparing your screenshots…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(32)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("ScreenStash is loading")
        .accessibilityIdentifier("startup.loading")
    }
}

private struct MainTabView: View {
    @State private var selectedTab = AppTab.inbox
    @State private var showResolvedCategory = UserDefaults.standard.bool(
        forKey: AppPreferenceKey.showResolvedCategory
    )

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                InboxView()
            }
            .tag(AppTab.inbox)
            .tabItem {
                Label(AppTab.inbox.title, systemImage: AppTab.inbox.symbolName)
            }

            NavigationStack {
                CategoriesView(showResolvedCategory: $showResolvedCategory)
            }
            .tag(AppTab.categories)
            .tabItem {
                Label(AppTab.categories.title, systemImage: AppTab.categories.symbolName)
            }

            NavigationStack {
                SearchView()
            }
            .tag(AppTab.search)
            .tabItem {
                Label(AppTab.search.title, systemImage: AppTab.search.symbolName)
            }

            NavigationStack {
                SettingsView(showResolvedCategory: $showResolvedCategory)
            }
            .tag(AppTab.settings)
            .tabItem {
                Label(AppTab.settings.title, systemImage: AppTab.settings.symbolName)
            }
        }
        .onChange(of: showResolvedCategory) { _, newValue in
            UserDefaults.standard.set(
                newValue,
                forKey: AppPreferenceKey.showResolvedCategory
            )
        }
    }
}

#Preview {
    RootView()
        .modelContainer(PreviewData.container)
}

#Preview("Startup") {
    StartupLoadingView()
}
