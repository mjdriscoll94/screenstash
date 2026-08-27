import PhotosUI
import SwiftData
import SwiftUI

struct InboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appDependencies) private var dependencies

    @Query(sort: \ScreenshotItem.importedAt, order: .reverse)
    private var allItems: [ScreenshotItem]

    @AppStorage(AppPreferenceKey.defaultLayout)
    private var layoutRawValue = ScreenshotLayoutMode.grid.rawValue

    @AppStorage(AppPreferenceKey.defaultCategory)
    private var defaultCategoryKey = ScreenshotCategory.other.rawValue

    @State private var viewModel = InboxViewModel()
    @State private var importViewModel = ImportViewModel()
    @State private var pickerItems: [PhotosPickerItem] = []

    private var layout: ScreenshotLayoutMode {
        ScreenshotLayoutMode(rawValue: layoutRawValue) ?? .grid
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        @Bindable var importViewModel = importViewModel
        let displayedItems = viewModel.filteredItems(from: allItems)

        Group {
            if displayedItems.isEmpty {
                if showsGettingStartedEmptyState {
                    gettingStartedEmptyState
                } else {
                    EmptyStateView(
                        title: emptyTitle,
                        message: emptyMessage,
                        systemImage: viewModel.filter.symbolName
                    )
                }
            } else if layout == .grid {
                grid(items: displayedItems)
            } else {
                list(items: displayedItems)
            }
        }
        .navigationTitle(viewModel.isSelecting ? "\(viewModel.selectedIDs.count) Selected" : "Inbox")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier("inbox.screen")
        .searchable(text: $viewModel.query, prompt: "Search this inbox")
        .toolbar { inboxToolbar(displayedItems: displayedItems) }
        .safeAreaInset(edge: .top, spacing: 0) {
            if viewModel.filter != .all {
                activeFilterBar
            }
        }
        .overlay {
            if importViewModel.isImporting {
                ZStack {
                    Color.black.opacity(0.18).ignoresSafeArea()
                    ImportProgressView(
                        completedCount: importViewModel.completedCount,
                        totalCount: importViewModel.totalCount,
                        message: importViewModel.currentMessage,
                        progress: importViewModel.progress
                    )
                }
            }
        }
        .sheet(isPresented: $importViewModel.isReviewPresented) {
            ImportReviewView(items: importViewModel.importedItems)
        }
        .alert("Import Notice", isPresented: importSummaryBinding) {
            Button("OK") { importViewModel.clearSummary() }
        } message: {
            Text(importViewModel.summaryMessage ?? "")
        }
        .alert("Couldn't Save Changes", isPresented: inboxErrorBinding) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "Try again.")
        }
        .confirmationDialog(
            "Delete selected screenshots?",
            isPresented: $viewModel.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete \(viewModel.selectedIDs.count) Screenshots", role: .destructive) {
                Task {
                    await viewModel.deleteSelected(
                        in: allItems,
                        context: modelContext,
                        notifications: dependencies.notificationScheduler
                    )
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the selected screenshots from FrameFile. The originals in Photos are not affected.")
        }
        .onChange(of: pickerItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                await importViewModel.importSelections(
                    newItems,
                    in: modelContext,
                    dependencies: dependencies,
                    defaultCategoryKey: defaultCategoryKey
                )
                pickerItems = []
            }
        }
    }

    private func grid(items: [ScreenshotItem]) -> some View {
        GeometryReader { geometry in
            let columnWidth = ScreenshotGridLayout.columnWidth(for: geometry.size.width)

            ScrollView {
                LazyVGrid(
                    columns: ScreenshotGridLayout.columns(columnWidth: columnWidth),
                    spacing: ScreenshotGridLayout.spacing
                ) {
                    ForEach(items) { item in
                        itemDestination(item) {
                            ScreenshotCard(item: item)
                                .frame(width: columnWidth, alignment: .topLeading)
                                .clipped()
                                .overlay(alignment: .topTrailing) {
                                    if viewModel.isSelecting {
                                        selectionIndicator(isSelected: viewModel.selectedIDs.contains(item.id))
                                            .padding(8)
                                    }
                                }
                        }
                        .frame(width: columnWidth, alignment: .topLeading)
                        .clipped()
                        .accessibilityIdentifier("screenshot.card.\(item.id.uuidString.lowercased())")
                    }
                }
                .padding(.horizontal, ScreenshotGridLayout.horizontalPadding)
                .padding(.vertical, ScreenshotGridLayout.horizontalPadding)
            }
        }
    }

    private func list(items: [ScreenshotItem]) -> some View {
        List(items) { item in
            itemDestination(item) {
                HStack {
                    if viewModel.isSelecting {
                        selectionIndicator(isSelected: viewModel.selectedIDs.contains(item.id))
                    }
                    ScreenshotRow(item: item)
                }
                .contentShape(Rectangle())
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private func itemDestination<Label: View>(
        _ item: ScreenshotItem,
        @ViewBuilder label: () -> Label
    ) -> some View {
        if viewModel.isSelecting {
            Button {
                viewModel.toggleSelection(for: item)
            } label: {
                label()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select \(item.displayTitle)")
            .accessibilityValue(viewModel.selectedIDs.contains(item.id) ? "Selected" : "Not selected")
        } else {
            NavigationLink {
                ScreenshotDetailView(item: item)
            } label: {
                label()
            }
            .buttonStyle(.plain)
        }
    }

    private func selectionIndicator(isSelected: Bool) -> some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .background(.background, in: Circle())
            .accessibilityHidden(true)
    }

    @ToolbarContentBuilder
    private func inboxToolbar(displayedItems: [ScreenshotItem]) -> some ToolbarContent {
        if viewModel.isSelecting {
            ToolbarItemGroup(placement: .topBarLeading) {
                Button(viewModel.selectedIDs.count == displayedItems.count ? "Deselect All" : "Select All") {
                    viewModel.toggleAllSelections(in: displayedItems)
                }
                .disabled(displayedItems.isEmpty)

                Button(role: .destructive) {
                    viewModel.showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(viewModel.selectedIDs.isEmpty)
                .accessibilityLabel("Delete selected screenshots")
                .accessibilityIdentifier("inbox.delete.selected")
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button {
                        viewModel.favoriteSelected(in: allItems, context: modelContext)
                    } label: {
                        Label("Favorite", systemImage: "star")
                    }

                    Button {
                        Task {
                            await viewModel.resolveSelected(
                                in: allItems,
                                context: modelContext,
                                notifications: dependencies.notificationScheduler
                            )
                        }
                    } label: {
                        Label("Resolve", systemImage: "checkmark.circle")
                    }

                    Button {
                        Task {
                            await viewModel.archiveSelected(
                                in: allItems,
                                context: modelContext,
                                notifications: dependencies.notificationScheduler
                            )
                        }
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(viewModel.selectedIDs.isEmpty)
                .accessibilityLabel("Actions for selected screenshots")

                Button("Done") { viewModel.endSelecting() }
            }
        } else {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    ForEach(InboxFilter.allCases) { filter in
                        Button {
                            viewModel.filter = filter
                        } label: {
                            if filter == viewModel.filter {
                                Label(filter.title, systemImage: "checkmark")
                            } else {
                                Label(filter.title, systemImage: filter.symbolName)
                            }
                        }
                    }
                } label: {
                    Image(systemName: viewModel.filter == .all
                        ? "line.3.horizontal.decrease.circle"
                        : "line.3.horizontal.decrease.circle.fill")
                }
                .accessibilityLabel("Filter Inbox")

                Button {
                    layoutRawValue = (layout == .grid
                        ? ScreenshotLayoutMode.list
                        : ScreenshotLayoutMode.grid).rawValue
                } label: {
                    Image(systemName: layout == .grid ? "list.bullet" : "square.grid.2x2")
                }
                .accessibilityLabel(layout == .grid ? "Use list view" : "Use grid view")

                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: 50,
                    matching: .images
                ) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Import screenshots")
                .disabled(importViewModel.isImporting)
            }

            ToolbarItem(placement: .topBarLeading) {
                if !displayedItems.isEmpty {
                    Button("Select") { viewModel.beginSelecting() }
                        .accessibilityIdentifier("inbox.select")
                }
            }
        }
    }

    private var activeFilterBar: some View {
        HStack {
            Label(viewModel.filter.title, systemImage: viewModel.filter.symbolName)
                .font(.subheadline.weight(.medium))
            Spacer()
            Button("Clear") { viewModel.filter = .all }
                .font(.subheadline)
        }
        .padding(.horizontal)
        .padding(.vertical, 9)
        .background(.bar)
        .accessibilityElement(children: .contain)
    }

    private var emptyTitle: String {
        if !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "No Matches"
        }
        return viewModel.filter == .all ? "Your Inbox Is Clear" : "Nothing Here"
    }

    private var showsGettingStartedEmptyState: Bool {
        viewModel.filter == .all
            && viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var gettingStartedEmptyState: some View {
        ContentUnavailableView {
            Label("Your Inbox Is Clear", systemImage: "tray")
        } description: {
            Text("Import screenshots you already have, or learn how to send new screenshots directly to FrameFile.")
        } actions: {
            VStack(spacing: 12) {
                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: 50,
                    matching: .images
                ) {
                    Label("Import Existing Screenshots", systemImage: "photo.on.rectangle.angled")
                }
                .buttonStyle(.borderedProminent)
                .disabled(importViewModel.isImporting)
                .accessibilityIdentifier("inbox.empty.importExisting")

                NavigationLink {
                    HowToUseScreenStashView()
                } label: {
                    Label("Learn How to Share New Screenshots", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("inbox.empty.shareGuide")
            }
        }
    }

    private var emptyMessage: String {
        if !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Try another search term or clear the current filter."
        }
        return viewModel.filter == .all
            ? "Import existing screenshots or share new ones directly to FrameFile."
            : "No unresolved screenshots match the \(viewModel.filter.title) filter."
    }

    private var importSummaryBinding: Binding<Bool> {
        Binding(
            get: { !importViewModel.isReviewPresented && importViewModel.summaryMessage != nil },
            set: { if !$0 { importViewModel.clearSummary() } }
        )
    }

    private var inboxErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

#Preview {
    NavigationStack {
        InboxView()
    }
    .modelContainer(PreviewData.container)
}
