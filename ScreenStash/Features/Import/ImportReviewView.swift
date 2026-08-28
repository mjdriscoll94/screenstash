import SwiftData
import SwiftUI

struct ImportReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appDependencies) private var dependencies

    @Query(sort: \ScreenshotCategoryRecord.sortOrder)
    private var categories: [ScreenshotCategoryRecord]

    let items: [ScreenshotItem]

    @State private var currentIndex = 0
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showCloseConfirmation = false
    @State private var reminderDraft: Date? = nil

    private var currentItem: ScreenshotItem? {
        items.indices.contains(currentIndex) ? items[currentIndex] : nil
    }

    private var currentItemHasTitle: Bool {
        guard let currentItem else { return false }
        return !currentItem.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if let currentItem {
                    ImportReviewEditor(
                        item: currentItem,
                        categories: categories,
                        reminderDate: $reminderDraft
                    )
                } else {
                    EmptyStateView(
                        title: "Review Complete",
                        message: "Your screenshots are ready in the Inbox.",
                        systemImage: "checkmark.circle"
                    )
                }
            }
            .navigationTitle("Review \(min(currentIndex + 1, items.count)) of \(items.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        showCloseConfirmation = currentIndex < items.count
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(currentIndex == items.count - 1 ? "Done" : "Next") {
                        Task { await saveAndAdvance() }
                    }
                    .disabled(isSaving || !currentItemHasTitle)
                }
            }
            .overlay {
                if isSaving {
                    LoadingOverlay(message: "Saving screenshot…")
                }
            }
            .confirmationDialog(
                "Finish reviewing later?",
                isPresented: $showCloseConfirmation,
                titleVisibility: .visible
            ) {
                Button("Finish Later") { dismiss() }
                Button("Keep Reviewing", role: .cancel) {}
            } message: {
                Text("Unreviewed screenshots will remain in the Unsorted Inbox filter.")
            }
            .alert("Couldn't Save", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Try again.")
            }
            .onChange(of: currentIndex) { _, _ in
                reminderDraft = currentItem?.reminderDate
            }
            .frameFileScreenBackground()
        }
        .interactiveDismissDisabled(isSaving)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    @MainActor
    private func saveAndAdvance() async {
        guard let item = currentItem else { return }
        let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        isSaving = true
        defer { isSaving = false }

        item.title = title

        if let reminderDate = reminderDraft {
            do {
                try await dependencies.notificationScheduler.scheduleReminder(
                    for: item.id,
                    title: item.displayTitle,
                    at: reminderDate
                )
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }

        item.reminderDate = reminderDraft
        item.isReviewed = true
        item.updatedAt = .now

        do {
            try modelContext.save()
        } catch {
            if reminderDraft != nil {
                await dependencies.notificationScheduler.cancelReminder(for: item.id)
                item.reminderDate = nil
            }
            errorMessage = error.localizedDescription
            return
        }

        if currentIndex == items.count - 1 {
            dismiss()
        } else {
            currentIndex += 1
        }
    }
}

private struct ImportReviewEditor: View {
    @Bindable var item: ScreenshotItem
    let categories: [ScreenshotCategoryRecord]
    @Binding var reminderDate: Date?

    var body: some View {
        Form {
            Section {
                ScreenshotThumbnail(data: item.imageData)
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: ScreenStashTheme.imageCornerRadius))
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section {
                TextField("Title", text: $item.title, axis: .vertical)
                    .textInputAutocapitalization(.sentences)
                    .accessibilityLabel("Screenshot title")

                Picker("Category", selection: $item.category) {
                    Text("Unsorted").tag(nil as ScreenshotCategoryRecord?)
                    ForEach(categories) { category in
                        Label(category.name, systemImage: category.symbolName)
                            .tag(category as ScreenshotCategoryRecord?)
                    }
                }

                TextField("Notes", text: $item.notes, axis: .vertical)
                    .lineLimit(3...8)
            } header: {
                Text("Details")
            } footer: {
                if item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Add a title before continuing.")
                }
            }

            Section("Reminder") {
                Toggle("Add reminder", isOn: reminderToggle)
                if reminderDate != nil {
                    DatePicker(
                        "Date and time",
                        selection: reminderDateBinding,
                        in: Date.now...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
            }

        }
        .scrollContentBackground(.hidden)
        .frameFileScreenBackground()
    }

    private var reminderToggle: Binding<Bool> {
        Binding(
            get: { reminderDate != nil },
            set: { enabled in
                reminderDate = enabled
                    ? Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now.addingTimeInterval(86_400)
                    : nil
            }
        )
    }

    private var reminderDateBinding: Binding<Date> {
        Binding(
            get: { reminderDate ?? .now.addingTimeInterval(86_400) },
            set: { reminderDate = $0 }
        )
    }
}
