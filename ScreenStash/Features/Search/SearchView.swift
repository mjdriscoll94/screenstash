import SwiftData
import SwiftUI

struct SearchView: View {
    @Query(sort: \ScreenshotItem.importedAt, order: .reverse)
    private var items: [ScreenshotItem]

    @Query(sort: \ScreenshotCategoryRecord.sortOrder)
    private var categories: [ScreenshotCategoryRecord]

    @State private var viewModel = SearchViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel
        let results = viewModel.results(from: items)

        Group {
            if !viewModel.isSearching {
                EmptyStateView(
                    title: "Find Any Screenshot",
                    message: "Search titles, notes, categories, and text recognized on-device.",
                    systemImage: "text.magnifyingglass"
                )
            } else if results.isEmpty {
                EmptyStateView(
                    title: "No Results",
                    message: "Try another phrase or clear one of the search filters.",
                    systemImage: "magnifyingglass"
                )
            } else {
                List(results) { item in
                    NavigationLink {
                        ScreenshotDetailView(item: item)
                    } label: {
                        SearchResultRow(
                            item: item,
                            reason: viewModel.matchReason(for: item) ?? .filters
                        )
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .frameFileScreenBackground()
        .navigationTitle("Search")
        .accessibilityIdentifier("search.screen")
        .searchable(text: $viewModel.query, prompt: "Text, title, notes, or category")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.isFilterPresented = true
                } label: {
                    Image(systemName: viewModel.hasFilters
                        ? "line.3.horizontal.decrease.circle.fill"
                        : "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel("Search filters")
                .accessibilityValue(viewModel.hasFilters ? "Filters active" : "No filters")
            }
        }
        .sheet(isPresented: $viewModel.isFilterPresented) {
            SearchFilterView(viewModel: viewModel, categories: categories)
        }
    }
}

private struct SearchResultRow: View {
    let item: ScreenshotItem
    let reason: SearchMatchReason

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScreenshotRow(item: item)
            Label(reason.rawValue, systemImage: "checkmark.circle")
                .font(.caption.weight(.medium))
                .foregroundStyle(ScreenStashTheme.brandBlue)
                .accessibilityLabel("Matched in \(reason.rawValue)")
        }
        .padding(11)
        .frameFileCard()
    }
}

private struct SearchFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: SearchViewModel
    let categories: [ScreenshotCategoryRecord]

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    Picker("Category", selection: $viewModel.categoryKey) {
                        Text("All Categories").tag(nil as String?)
                        ForEach(categories) { category in
                            Label(category.name, systemImage: category.symbolName)
                                .tag(category.key as String?)
                        }
                    }
                }

                Section("Date Imported") {
                    Picker("Date imported", selection: $viewModel.dateFilter) {
                        ForEach(ImportedDateFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                }

                Section("Status") {
                    Picker("Status", selection: $viewModel.status) {
                        Text("Any Status").tag(nil as ScreenshotStatus?)
                        ForEach(ScreenshotStatus.allCases) { status in
                            Label(status.displayName, systemImage: status.symbolName)
                                .tag(status as ScreenshotStatus?)
                        }
                    }
                }

                Section("Other") {
                    Toggle("Favorites only", isOn: $viewModel.favoritesOnly)
                    Picker("Reminders", selection: $viewModel.reminderFilter) {
                        ForEach(ReminderSearchFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                }

                if viewModel.hasFilters {
                    Section {
                        Button("Reset Filters", role: .destructive) {
                            viewModel.resetFilters()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .frameFileScreenBackground()
            .navigationTitle("Search Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    NavigationStack {
        SearchView()
    }
    .modelContainer(PreviewData.container)
}
