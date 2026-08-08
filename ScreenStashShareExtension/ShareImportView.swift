import SwiftUI
import UIKit

struct ShareImportView: View {
    let viewModel: ShareImportViewModel

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Group {
                switch viewModel.phase {
                case .loading:
                    ProgressView("Loading screenshot…")
                case .ready, .saving:
                    importForm(viewModel: viewModel)
                case let .failed(message):
                    ContentUnavailableView {
                        Label("Couldn't Add Screenshot", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Close", action: viewModel.cancel)
                    }
                }
            }
            .navigationTitle("Add to ScreenStash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: viewModel.cancel)
                }
            }
        }
        .task { await viewModel.loadIfNeeded() }
    }

    private func importForm(viewModel: ShareImportViewModel) -> some View {
        Form {
            Section {
                if let first = viewModel.screenshots.first,
                   let image = UIImage(data: first.data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .accessibilityLabel(previewAccessibilityLabel)
                }

                if viewModel.screenshots.count > 1 {
                    Label(
                        "\(viewModel.screenshots.count) screenshots selected",
                        systemImage: "photo.stack"
                    )
                }
            }

            Section {
                ForEach(Array(viewModel.screenshots.enumerated()), id: \.element.id) { index, screenshot in
                    TextField(
                        viewModel.screenshots.count == 1
                            ? "Screenshot title"
                            : "Screenshot \(index + 1) title",
                        text: titleBinding(for: screenshot.id, in: viewModel)
                    )
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .accessibilityLabel(
                        viewModel.screenshots.count == 1
                            ? "Screenshot title"
                            : "Title for screenshot \(index + 1)"
                    )
                }
            } header: {
                Text(viewModel.screenshots.count == 1 ? "Title" : "Titles")
            } footer: {
                Text("Add a title that will make this screenshot easy to recognize later.")
            }

            Section("Category") {
                Picker("Category", selection: Bindable(viewModel).selectedCategoryKey) {
                    ForEach(viewModel.categories) { category in
                        Label(category.name, systemImage: category.symbolName)
                            .tag(category.key)
                    }
                }
                .pickerStyle(.navigationLink)
            }

            Section {
                Button {
                    Task { await viewModel.save() }
                } label: {
                    HStack {
                        Spacer()
                        if viewModel.phase == .saving {
                            ProgressView()
                        } else {
                            Label("Add to ScreenStash", systemImage: "tray.and.arrow.down")
                        }
                        Spacer()
                    }
                }
                .disabled(viewModel.phase == .saving || !viewModel.canSave)
                .accessibilityHint(
                    viewModel.canSave
                        ? "Saves the selected screenshot in the chosen category"
                        : "Enter a title before saving"
                )
            } footer: {
                Text("ScreenStash will privately finish image processing and on-device text recognition for search when you open the app.")
            }
        }
    }

    private func titleBinding(
        for screenshotID: UUID,
        in viewModel: ShareImportViewModel
    ) -> Binding<String> {
        Binding(
            get: {
                viewModel.screenshots.first(where: { $0.id == screenshotID })?.title ?? ""
            },
            set: { newValue in
                guard let index = viewModel.screenshots.firstIndex(where: { $0.id == screenshotID }) else {
                    return
                }
                viewModel.screenshots[index].title = newValue
            }
        )
    }

    private var previewAccessibilityLabel: String {
        viewModel.screenshots.count == 1
            ? "Selected screenshot preview"
            : "Preview of the first selected screenshot"
    }
}
