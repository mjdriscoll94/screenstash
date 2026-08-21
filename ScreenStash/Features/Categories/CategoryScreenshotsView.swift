import SwiftData
import SwiftUI

struct CategoryScreenshotsView: View {
    let categoryKey: String
    let categoryName: String
    let symbolName: String

    @Query(sort: \ScreenshotItem.importedAt, order: .reverse)
    private var allItems: [ScreenshotItem]

    private var items: [ScreenshotItem] {
        allItems.filter { item in
            item.category?.key == categoryKey
                && item.isUnresolved
        }
    }

    var body: some View {
        ScreenshotCollectionView(
            items: items,
            title: categoryName,
            emptyTitle: "No \(categoryName) Screenshots",
            emptyMessage: "There are no active screenshots in this category.",
            symbolName: symbolName
        )
    }
}

struct ResolvedScreenshotsView: View {
    @Query(sort: \ScreenshotItem.updatedAt, order: .reverse)
    private var allItems: [ScreenshotItem]

    private var items: [ScreenshotItem] {
        allItems.filter { $0.status == .resolved }
    }

    var body: some View {
        ScreenshotCollectionView(
            items: items,
            title: "Resolved",
            emptyTitle: "No Resolved Screenshots",
            emptyMessage: "Screenshots you mark resolved will appear here.",
            symbolName: ScreenshotStatus.resolved.symbolName
        )
    }
}

private struct ScreenshotCollectionView: View {
    let items: [ScreenshotItem]
    let title: String
    let emptyTitle: String
    let emptyMessage: String
    let symbolName: String

    @AppStorage(AppPreferenceKey.defaultLayout)
    private var layoutRawValue = ScreenshotLayoutMode.grid.rawValue
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appDependencies) private var dependencies

    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    private var layout: ScreenshotLayoutMode {
        ScreenshotLayoutMode(rawValue: layoutRawValue) ?? .grid
    }

    var body: some View {
        Group {
            if items.isEmpty {
                EmptyStateView(
                    title: emptyTitle,
                    message: emptyMessage,
                    systemImage: symbolName
                )
            } else if layout == .grid {
                grid
            } else {
                list
            }
        }
        .navigationTitle(isSelecting ? "\(selectedIDs.count) Selected" : title)
        .toolbar { collectionToolbar }
        .confirmationDialog(
            "Delete selected screenshots?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(deleteButtonTitle, role: .destructive) {
                Task { await deleteSelected() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the selected screenshots from ScreenStash. The originals in Photos are not affected.")
        }
        .alert("Couldn't Delete Screenshots", isPresented: errorBinding) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Try again.")
        }
        .overlay {
            if isDeleting {
                ZStack {
                    Color.black.opacity(0.12).ignoresSafeArea()
                    LoadingOverlay(message: "Deleting screenshots…")
                }
            }
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12, alignment: .top),
                    GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12, alignment: .top)
                ],
                spacing: 12
            ) {
                ForEach(items) { item in
                    itemDestination(item) {
                        ScreenshotCard(item: item)
                            .overlay(alignment: .topTrailing) {
                                if isSelecting {
                                    selectionIndicator(for: item)
                                        .padding(8)
                                }
                            }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .clipped()
                }
            }
            .padding()
        }
    }

    private var list: some View {
        List(items) { item in
            itemDestination(item) {
                HStack {
                    if isSelecting {
                        selectionIndicator(for: item)
                    }
                    ScreenshotRow(item: item)
                }
                .contentShape(Rectangle())
            }
        }
        .listStyle(.plain)
    }

    @ToolbarContentBuilder
    private var collectionToolbar: some ToolbarContent {
        if isSelecting {
            ToolbarItemGroup(placement: .topBarLeading) {
                Button(selectedIDs.count == items.count ? "Deselect All" : "Select All") {
                    toggleAllSelections()
                }
                .disabled(items.isEmpty)

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(selectedIDs.isEmpty || isDeleting)
                .accessibilityLabel("Delete selected screenshots")
                .accessibilityIdentifier("collection.delete.selected")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { endSelecting() }
            }
        } else {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    layoutRawValue = (layout == .grid
                        ? ScreenshotLayoutMode.list
                        : ScreenshotLayoutMode.grid).rawValue
                } label: {
                    Image(systemName: layout == .grid ? "list.bullet" : "square.grid.2x2")
                }
                .accessibilityLabel(layout == .grid ? "Use list view" : "Use grid view")

                if !items.isEmpty {
                    Button("Select") { isSelecting = true }
                        .accessibilityIdentifier("collection.select")
                }
            }
        }
    }

    @ViewBuilder
    private func itemDestination<Label: View>(
        _ item: ScreenshotItem,
        @ViewBuilder label: () -> Label
    ) -> some View {
        if isSelecting {
            Button {
                toggleSelection(for: item)
            } label: {
                label()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select \(item.displayTitle)")
            .accessibilityValue(selectedIDs.contains(item.id) ? "Selected" : "Not selected")
        } else {
            NavigationLink {
                ScreenshotDetailView(item: item)
            } label: {
                label()
            }
            .buttonStyle(.plain)
        }
    }

    private func selectionIndicator(for item: ScreenshotItem) -> some View {
        let isSelected = selectedIDs.contains(item.id)
        return Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .background(.background, in: Circle())
            .accessibilityHidden(true)
    }

    private func toggleSelection(for item: ScreenshotItem) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }

    private func toggleAllSelections() {
        if selectedIDs.count == items.count {
            selectedIDs.removeAll()
        } else {
            selectedIDs = Set(items.map(\.id))
        }
    }

    private func endSelecting() {
        isSelecting = false
        selectedIDs.removeAll()
    }

    private var deleteButtonTitle: String {
        let count = selectedIDs.count
        return count == 1 ? "Delete Screenshot" : "Delete \(count) Screenshots"
    }

    @MainActor
    private func deleteSelected() async {
        guard !selectedIDs.isEmpty else { return }
        isDeleting = true
        defer { isDeleting = false }

        let selectedItems = items.filter { selectedIDs.contains($0.id) }
        for item in selectedItems {
            await dependencies.notificationScheduler.cancelReminder(for: item.id)
            modelContext.delete(item)
        }

        do {
            try modelContext.save()
            endSelecting()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}
