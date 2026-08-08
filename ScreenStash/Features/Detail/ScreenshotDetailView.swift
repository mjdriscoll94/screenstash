import SwiftData
import SwiftUI

struct ScreenshotDetailView: View {
    private enum ConfirmationAction {
        case resolve
        case archive
        case delete
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appDependencies) private var dependencies

    @Query(sort: \ScreenshotCategoryRecord.sortOrder)
    private var categories: [ScreenshotCategoryRecord]

    @Bindable var item: ScreenshotItem
    @State private var viewModel: ScreenshotDetailViewModel
    @State private var confirmationAction: ConfirmationAction?

    init(item: ScreenshotItem) {
        self.item = item
        _viewModel = State(initialValue: ScreenshotDetailViewModel(item: item))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ZoomableImageView(imageData: item.imageData)
                    .frame(height: 430)

                detailsSection
                reminderSection(viewModel: viewModel)
                actionsSection
            }
            .padding()
        }
        .navigationTitle(item.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("detail.screen")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    item.isFavorite.toggle()
                    viewModel.saveEdits(for: item, context: modelContext)
                } label: {
                    Image(systemName: item.isFavorite ? "star.fill" : "star")
                }
                .accessibilityLabel(item.isFavorite ? "Remove from favorites" : "Add to favorites")

                ShareLink(
                    item: ShareableScreenshot(data: item.imageData),
                    preview: SharePreview(item.displayTitle)
                ) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share screenshot")
            }
        }
        .overlay {
            if viewModel.isWorking {
                ZStack {
                    Color.black.opacity(0.12).ignoresSafeArea()
                    LoadingOverlay(message: "Saving changes…")
                }
            }
        }
        .confirmationDialog(
            confirmationTitle,
            isPresented: confirmationBinding,
            titleVisibility: .visible
        ) {
            confirmationButtons
            Button("Cancel", role: .cancel) { confirmationAction = nil }
        } message: {
            Text(confirmationMessage)
        }
        .alert("Couldn't Complete Action", isPresented: errorBinding) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "Try again.")
        }
        .onDisappear {
            if !item.isDeleted {
                viewModel.saveEdits(for: item, context: modelContext)
            }
        }
    }

    private var detailsSection: some View {
        GroupBox("Details") {
            VStack(alignment: .leading, spacing: 14) {
                TextField("Title", text: $item.title, axis: .vertical)
                    .textFieldStyle(.roundedBorder)

                Picker("Category", selection: $item.category) {
                    Text("Unsorted").tag(nil as ScreenshotCategoryRecord?)
                    ForEach(categories) { category in
                        Label(category.name, systemImage: category.symbolName)
                            .tag(category as ScreenshotCategoryRecord?)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes")
                        .font(.subheadline.weight(.medium))
                    TextEditor(text: $item.notes)
                        .frame(minHeight: 100)
                        .padding(5)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.25))
                        )
                        .accessibilityLabel("Screenshot notes")
                }

                LabeledContent("Status") {
                    Label(item.status.displayName, systemImage: item.status.symbolName)
                }
                LabeledContent("Imported") {
                    Text(item.importedAt, format: .dateTime.month().day().year())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
        }
    }

    private func reminderSection(viewModel: ScreenshotDetailViewModel) -> some View {
        GroupBox("Reminder") {
            VStack(alignment: .leading, spacing: 12) {
                if let savedDate = item.reminderDate {
                    savedReminderRow(savedDate, viewModel: viewModel)

                    Divider()

                    Text("Change reminder")
                        .font(.subheadline.weight(.semibold))
                } else {
                    Text("Choose when ScreenStash should remind you about this screenshot.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                DatePicker(
                    "Date and time",
                    selection: $viewModel.reminderDraft,
                    in: Date.now...,
                    displayedComponents: [.date, .hourAndMinute]
                )

                HStack {
                    reminderPreset("Tomorrow", date: tomorrowDate)
                    reminderPreset("Weekend", date: weekendDate)
                }
                .buttonStyle(.bordered)

                Button(item.reminderDate == nil ? "Save Reminder" : "Update Reminder") {
                    Task {
                        await viewModel.saveReminder(
                            for: item,
                            context: modelContext,
                            notifications: dependencies.notificationScheduler
                        )
                    }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("detail.reminder.save")

                if let message = viewModel.reminderConfirmationMessage {
                    Label(message, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("detail.reminder.confirmation")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
            .animation(.default, value: item.reminderDate)
        }
    }

    private func savedReminderRow(
        _ date: Date,
        viewModel: ScreenshotDetailViewModel
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "bell.badge.fill")
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Saved reminder")
                        .font(.headline)
                    Text(date, format: .dateTime.weekday(.wide).month(.wide).day().year())
                    Text(date, format: .dateTime.hour().minute())
                        .foregroundStyle(.secondary)
                }
            }

            Button("Remove Reminder", role: .destructive) {
                Task {
                    await viewModel.removeReminder(
                        for: item,
                        context: modelContext,
                        notifications: dependencies.notificationScheduler
                    )
                }
            }
            .buttonStyle(.bordered)
            .accessibilityHint("Cancels this notification and removes its saved date")
            .accessibilityIdentifier("detail.reminder.remove")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("detail.reminder.saved")
    }

    private var actionsSection: some View {
        GroupBox("Actions") {
            VStack(spacing: 10) {
                if item.status == .resolved || item.status == .archived {
                    Button {
                        if viewModel.reopen(item, context: modelContext) {
                            dismiss()
                        }
                    } label: {
                        Label("Return to Active", systemImage: "arrow.uturn.backward.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        confirmationAction = .resolve
                    } label: {
                        Label("Mark Resolved", systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("detail.resolve")

                    Button {
                        confirmationAction = .archive
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                Button(role: .destructive) {
                    confirmationAction = .delete
                } label: {
                    Label("Delete from ScreenStash", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 8)
        }
    }

    private func reminderPreset(_ title: String, date: Date) -> some View {
        Button(title) {
            viewModel.reminderDraft = date
            viewModel.reminderConfirmationMessage = nil
        }
        .accessibilityLabel("Remind me \(title.lowercased())")
    }

    @ViewBuilder
    private var confirmationButtons: some View {
        switch confirmationAction {
        case .resolve:
            Button("Mark Resolved") {
                Task {
                    if await viewModel.resolve(
                        item,
                        context: modelContext,
                        notifications: dependencies.notificationScheduler
                    ) {
                        dismiss()
                    }
                }
            }
        case .archive:
            Button("Archive") {
                Task {
                    if await viewModel.archive(
                        item,
                        context: modelContext,
                        notifications: dependencies.notificationScheduler
                    ) {
                        dismiss()
                    }
                }
            }
        case .delete:
            Button("Delete", role: .destructive) {
                Task {
                    if await viewModel.delete(
                        item,
                        context: modelContext,
                        notifications: dependencies.notificationScheduler
                    ) {
                        dismiss()
                    }
                }
            }
        case nil:
            EmptyView()
        }
    }

    private var confirmationBinding: Binding<Bool> {
        Binding(
            get: { confirmationAction != nil },
            set: { if !$0 { confirmationAction = nil } }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private var confirmationTitle: String {
        switch confirmationAction {
        case .resolve: "Mark this screenshot resolved?"
        case .archive: "Archive this screenshot?"
        case .delete: "Delete this screenshot?"
        case nil: "Confirm Action"
        }
    }

    private var confirmationMessage: String {
        switch confirmationAction {
        case .resolve: "Its reminder will be removed and it will leave the Inbox."
        case .archive: "Its reminder will be removed and it will leave the Inbox."
        case .delete: "This removes the ScreenStash copy. The original in Photos is not affected."
        case nil: ""
        }
    }

    private var tomorrowDate: Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)
            .flatMap { Calendar.current.date(byAdding: .day, value: 1, to: $0) }
            ?? .now.addingTimeInterval(86_400)
    }

    private var weekendDate: Date {
        let calendar = Calendar.current
        let nextSaturday = calendar.nextDate(
            after: .now,
            matching: DateComponents(hour: 9, weekday: 7),
            matchingPolicy: .nextTime
        )
        return nextSaturday ?? .now.addingTimeInterval(3 * 86_400)
    }
}
