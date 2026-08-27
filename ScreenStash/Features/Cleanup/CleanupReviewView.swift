import SwiftData
import SwiftUI

struct CleanupReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appDependencies) private var dependencies

    @Query(sort: \ScreenshotItem.createdAt)
    private var allItems: [ScreenshotItem]

    @AppStorage(AppPreferenceKey.agingThreshold)
    private var thresholdDays = ScreenshotAgingThreshold.thirtyDays.rawValue

    @State private var viewModel = CleanupViewModel()

    private var candidates: [ScreenshotItem] {
        viewModel.candidates(from: allItems, thresholdDays: thresholdDays)
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        Group {
            if let item = candidates.first {
                ScrollView {
                    VStack(spacing: 18) {
                        cleanupHeader(item: item)

                        ScreenshotThumbnail(data: item.imageData)
                            .scaledToFit()
                            .frame(maxHeight: 440)
                            .clipShape(RoundedRectangle(cornerRadius: ScreenStashTheme.imageCornerRadius))
                            .accessibilityLabel("Screenshot: \(item.displayTitle)")

                        VStack(spacing: 10) {
                            Button {
                                viewModel.keep(item, context: modelContext)
                            } label: {
                                Label("Keep", systemImage: "hand.thumbsup")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)

                            HStack {
                                cleanupButton("Resolve", symbol: "checkmark.circle") {
                                    Task {
                                        await viewModel.resolve(
                                            item,
                                            context: modelContext,
                                            notifications: dependencies.notificationScheduler
                                        )
                                    }
                                }
                                cleanupButton("Archive", symbol: "archivebox") {
                                    Task {
                                        await viewModel.archive(
                                            item,
                                            context: modelContext,
                                            notifications: dependencies.notificationScheduler
                                        )
                                    }
                                }
                            }

                            Button {
                                viewModel.isReminderPresented = true
                            } label: {
                                Label("Add Reminder", systemImage: "bell")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Button(role: .destructive) {
                                viewModel.showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                }
            } else {
                EmptyStateView(
                    title: "Cleanup Complete",
                    message: "There are no unresolved screenshots older than \(thresholdDays) days to review.",
                    systemImage: "sparkles"
                )
            }
        }
        .navigationTitle("Cleanup")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isWorking {
                ZStack {
                    Color.black.opacity(0.12).ignoresSafeArea()
                    LoadingOverlay(message: "Updating screenshot…")
                }
            }
        }
        .sheet(isPresented: $viewModel.isReminderPresented) {
            if let item = candidates.first {
                NavigationStack {
                    Form {
                        DatePicker(
                            "Remind me",
                            selection: $viewModel.reminderDate,
                            in: Date.now...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                    .navigationTitle("Add Reminder")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { viewModel.isReminderPresented = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Schedule") {
                                Task {
                                    await viewModel.addReminder(
                                        to: item,
                                        context: modelContext,
                                        notifications: dependencies.notificationScheduler
                                    )
                                }
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
        .confirmationDialog(
            "Delete this screenshot?",
            isPresented: $viewModel.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            if let item = candidates.first {
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.delete(
                            item,
                            context: modelContext,
                            notifications: dependencies.notificationScheduler
                        )
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the FrameFile copy. The original in Photos is not affected.")
        }
        .alert("Couldn't Complete Action", isPresented: errorBinding) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "Try again.")
        }
    }

    private func cleanupHeader(item: ScreenshotItem) -> some View {
        VStack(spacing: 7) {
            Text(item.displayTitle)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            let days = AgingCalculator.daysOld(createdAt: item.createdAt)
            Label("\(days) days old", systemImage: "calendar")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text("\(max(candidates.count - 1, 0)) more after this")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
    }

    private func cleanupButton(
        _ title: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}
