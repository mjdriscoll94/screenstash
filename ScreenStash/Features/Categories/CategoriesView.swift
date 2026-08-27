import SwiftData
import SwiftUI

struct CategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appDependencies) private var dependencies

    @Query(sort: \ScreenshotCategoryRecord.sortOrder)
    private var categories: [ScreenshotCategoryRecord]

    @Query private var items: [ScreenshotItem]
    @AppStorage(AppPreferenceKey.defaultCategory)
    private var defaultCategoryKey = ScreenshotCategory.other.rawValue
    @Binding var showResolvedCategory: Bool

    @State private var viewModel = CategoriesViewModel()
    @State private var editorDraft: CategoryEditorDraft?
    @State private var pendingDeletion: ScreenshotCategoryRecord?
    @State private var errorMessage: String?

    var body: some View {
        let resolvedItems = viewModel.resolvedItems(from: items)

        Group {
            if categories.isEmpty && !showResolvedCategory {
                ContentUnavailableView {
                    Label("No Categories", systemImage: "tag.slash")
                } description: {
                    Text("Create a category with the plus button. Screenshots can still be kept Unsorted.")
                }
            } else {
                List {
                    if showResolvedCategory {
                        Section("Status") {
                            NavigationLink {
                                ResolvedScreenshotsView()
                            } label: {
                                CategorySummaryRow(
                                    name: "Resolved",
                                    symbolName: ScreenshotStatus.resolved.symbolName,
                                    count: resolvedItems.count,
                                    recentItems: Array(resolvedItems.prefix(3)),
                                    countDescription: "resolved screenshots"
                                )
                                .accessibilityIdentifier("category.row.Resolved")
                            }
                        }
                    }

                    if !categories.isEmpty {
                        Section {
                            ForEach(categories) { category in
                                let activeItems = viewModel.activeItems(for: category, from: items)

                                if pendingDeletion === category {
                                    CategoryDeletionPrompt(
                                        categoryName: category.name,
                                        message: deletionMessage(for: category),
                                        onDelete: deletePendingCategory,
                                        onCancel: { pendingDeletion = nil }
                                    )
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }

                                NavigationLink {
                                    CategoryScreenshotsView(
                                        categoryKey: category.key,
                                        categoryName: category.name,
                                        symbolName: category.symbolName
                                    )
                                } label: {
                                    CategorySummaryRow(
                                        name: category.name,
                                        symbolName: category.symbolName,
                                        count: activeItems.count,
                                        recentItems: Array(activeItems.prefix(3)),
                                        countDescription: "active screenshots"
                                    )
                                    .accessibilityIdentifier("category.row.\(category.name)")
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        pendingDeletion = category
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        editorDraft = CategoryEditorDraft(category: category)
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.accentColor)
                                }
                                .contextMenu {
                                    Button {
                                        editorDraft = CategoryEditorDraft(category: category)
                                    } label: {
                                        Label("Edit Category", systemImage: "pencil")
                                    }

                                    Button(role: .destructive) {
                                        pendingDeletion = category
                                    } label: {
                                        Label("Delete Category", systemImage: "trash")
                                    }
                                }
                            }
                        } footer: {
                            Text("Swipe right to edit. Swipe left to delete.")
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editorDraft = CategoryEditorDraft(category: nil)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add category")
                .accessibilityIdentifier("category.add")
            }
        }
        .sheet(item: $editorDraft) { draft in
            CategoryEditorView(category: draft.category) { name, symbolName in
                try saveCategory(draft.category, name: name, symbolName: symbolName)
            }
        }
        .alert("Couldn't Update Categories", isPresented: errorBinding) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Try again.")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func deletionMessage(for category: ScreenshotCategoryRecord) -> String {
        let count = items.filter { $0.category?.key == category.key }.count
        if count == 0 {
            return "This cannot be undone."
        }
        let noun = count == 1 ? "screenshot" : "screenshots"
        return "\(count) \(noun) will become Unsorted. The screenshots themselves will not be deleted."
    }

    @MainActor
    private func saveCategory(
        _ category: ScreenshotCategoryRecord?,
        name: String,
        symbolName: String
    ) throws {
        if let category {
            try viewModel.updateCategory(
                category,
                name: name,
                symbolName: symbolName,
                categories: categories,
                context: modelContext
            )
        } else {
            try viewModel.addCategory(
                name: name,
                symbolName: symbolName,
                categories: categories,
                context: modelContext
            )
        }
        synchronizeSharedCatalog()
    }

    @MainActor
    private func deletePendingCategory() {
        guard let category = pendingDeletion else { return }
        let categoryKey = category.key
        let isBuiltIn = category.isBuiltIn
        let fallbackCategoryKey = categories.first { $0.key != categoryKey }?.key ?? ""

        do {
            try viewModel.deleteCategory(category, items: items, context: modelContext)
            if isBuiltIn {
                DeletedBuiltInCategoryStore.markDeleted(categoryKey)
            }
            if defaultCategoryKey == categoryKey {
                defaultCategoryKey = fallbackCategoryKey
            }
            pendingDeletion = nil
            synchronizeSharedCatalog()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func synchronizeSharedCatalog() {
        Task { @MainActor in
            do {
                try await SharedCategoryCatalogSynchronizer.sync(
                    in: modelContext,
                    catalog: dependencies.sharedCategoryCatalog
                )
            } catch {
                errorMessage = "The category was saved, but the share sheet could not be updated. Reopen FrameFile to retry."
            }
        }
    }
}

private struct CategoryDeletionPrompt: View {
    let categoryName: String
    let message: String
    let onDelete: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Delete \(categoryName)?", systemImage: "trash")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)

                Button("Delete Category", role: .destructive, action: onDelete)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.red.opacity(0.28), lineWidth: 1)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("category.delete.prompt")
    }
}

private struct CategorySummaryRow: View {
    let name: String
    let symbolName: String
    let count: Int
    let recentItems: [ScreenshotItem]
    let countDescription: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: symbolName)
                    .frame(width: 30)
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                Text(name)
                    .font(.headline)

                Spacer()

                Text(count, format: .number)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if !recentItems.isEmpty {
                HStack(spacing: 7) {
                    ForEach(recentItems) { item in
                        ScreenshotThumbnail(data: item.thumbnailData)
                            .frame(width: 42, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    if count > recentItems.count {
                        Text("+\(count - recentItems.count)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(count) \(countDescription)")
    }
}

#Preview {
    NavigationStack {
        CategoriesView(showResolvedCategory: .constant(true))
    }
    .modelContainer(PreviewData.container)
}
