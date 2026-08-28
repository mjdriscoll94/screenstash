import SwiftData
import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.openURL) private var openURL

    @Query(sort: \ScreenshotItem.importedAt)
    private var allItems: [ScreenshotItem]

    @Query(sort: \ScreenshotCategoryRecord.sortOrder)
    private var categories: [ScreenshotCategoryRecord]

    @AppStorage(AppPreferenceKey.defaultLayout)
    private var defaultLayout = ScreenshotLayoutMode.grid.rawValue

    @AppStorage(AppPreferenceKey.defaultCategory)
    private var defaultCategory = ScreenshotCategory.other.rawValue

    @Binding var showResolvedCategory: Bool

    @AppStorage(AppPreferenceKey.agingThreshold)
    private var agingThreshold = ScreenshotAgingThreshold.thirtyDays.rawValue

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var exportDocument = ScreenStashExportDocument()
    @State private var isExporting = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    private var cleanupCount: Int {
        allItems.filter {
            AgingCalculator.needsReview(item: $0, thresholdDays: agingThreshold)
        }.count
    }

    var body: some View {
        Form {
            Section("Display") {
                Picker("Default view", selection: $defaultLayout) {
                    ForEach(ScreenshotLayoutMode.allCases) { layout in
                        Text(layout.displayName).tag(layout.rawValue)
                    }
                }

                Toggle("Show Resolved Category", isOn: $showResolvedCategory)
                    .accessibilityHint("Shows or hides the Resolved collection on the Categories tab")
                    .accessibilityIdentifier("settings.showResolvedCategory")
            }

            Section("Importing") {
                Picker("Default category", selection: $defaultCategory) {
                    Text("Unsorted").tag("")
                    ForEach(categories) { category in
                        Label(category.name, systemImage: category.symbolName)
                            .tag(category.key)
                    }
                }

                NavigationLink {
                    CategoriesView(showResolvedCategory: $showResolvedCategory)
                } label: {
                    Label("Manage Categories", systemImage: "tag")
                }

                NavigationLink {
                    HowToUseScreenStashView()
                } label: {
                    Label("How to Use FrameFile", systemImage: "questionmark.circle")
                }

                Label("Share screenshots directly", systemImage: "square.and.arrow.up")
                Text("After taking a screenshot, open the share sheet and choose FrameFile. If it is hidden, tap More to enable it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Cleanup") {
                Picker("Aging threshold", selection: $agingThreshold) {
                    ForEach(ScreenshotAgingThreshold.allCases) { threshold in
                        Text(threshold.displayName).tag(threshold.rawValue)
                    }
                }

                NavigationLink {
                    CleanupReviewView()
                } label: {
                    LabeledContent {
                        Text(cleanupCount, format: .number)
                            .foregroundStyle(.secondary)
                    } label: {
                        Label("Review Aging Screenshots", systemImage: "clock.arrow.circlepath")
                    }
                }
            }

            Section("Notifications") {
                LabeledContent("Permission", value: notificationStatusDescription)
                Text("FrameFile asks for notification permission only when you create your first reminder. It does not send automatic cleanup alerts.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if notificationStatus == .denied {
                    Button("Open iOS Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                }
            }

            Section("Your Data") {
                Button {
                    prepareExport()
                } label: {
                    Label("Export FrameFile Data", systemImage: "square.and.arrow.up")
                }
                .disabled(allItems.isEmpty)

                Text("Export creates a .screenstash folder package containing JPEG images, OCR text files, and JSON metadata. It is not a ZIP archive.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete All App Data", systemImage: "trash")
                }
                .disabled(isDeleting)
                .accessibilityIdentifier("settings.deleteAllData")
            }

            Section("FrameFile") {
                NavigationLink("Privacy") {
                    PrivacyView()
                }
                NavigationLink("About") {
                    AboutView()
                }
            }
        }
        .scrollContentBackground(.hidden)
        .frameFileScreenBackground()
        .navigationTitle("Settings")
        .accessibilityIdentifier("settings.screen")
        .task { await refreshNotificationStatus() }
        .onChange(of: categories.map(\.key)) { _, categoryKeys in
            if !categoryKeys.contains(defaultCategory) {
                defaultCategory = categoryKeys.first ?? ""
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .screenStashExport,
            defaultFilename: "FrameFile Export.screenstash"
        ) { result in
            if case let .failure(error) = result {
                errorMessage = error.localizedDescription
            }
        }
        .confirmationDialog(
            "Delete all FrameFile data?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete All Data", role: .destructive) {
                Task { await deleteAllData() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes screenshots, custom categories, settings, reminders, and pending shared imports. Originals in Photos are not affected.")
        }
        .alert("Couldn't Complete Action", isPresented: errorBinding) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Try again.")
        }
        .overlay {
            if isDeleting {
                ZStack {
                    Color.black.opacity(0.12).ignoresSafeArea()
                    LoadingOverlay(message: "Deleting FrameFile data…")
                }
            }
        }
    }

    private var notificationStatusDescription: String {
        switch notificationStatus {
        case .notDetermined: "Not requested"
        case .denied: "Denied"
        case .authorized: "Allowed"
        case .provisional: "Provisional"
        case .ephemeral: "Temporary"
        @unknown default: "Unknown"
        }
    }

    private func prepareExport() {
        do {
            let payload = try dependencies.exportService.makePayload(from: allItems)
            exportDocument = ScreenStashExportDocument(payload: payload)
            isExporting = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func deleteAllData() async {
        isDeleting = true

        allItems.forEach(modelContext.delete)
        categories.forEach(modelContext.delete)

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
            isDeleting = false
            return
        }

        await dependencies.notificationScheduler.cancelAllReminders()

        do {
            try await dependencies.sharedImportQueue.removeAllImports()
        } catch {
            errorMessage = "Screenshots were deleted, but pending shared imports could not be removed: \(error.localizedDescription)"
        }

        AppPreferenceKey.resetAll()
        showResolvedCategory = false
        await BuiltInCategorySeeder.seedIfNeeded(in: modelContext, excluding: [])

        do {
            try await SharedCategoryCatalogSynchronizer.sync(
                in: modelContext,
                catalog: dependencies.sharedCategoryCatalog
            )
        } catch where errorMessage == nil {
            errorMessage = "App data was reset, but the share-sheet category list could not be refreshed. Reopen FrameFile to retry."
        } catch {}

        isDeleting = false
    }

    private func refreshNotificationStatus() async {
        notificationStatus = await dependencies.notificationScheduler.authorizationStatus()
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

#Preview {
    NavigationStack {
        SettingsView(showResolvedCategory: .constant(false))
    }
    .modelContainer(PreviewData.container)
}
