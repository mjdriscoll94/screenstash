import SwiftUI

struct CategoryEditorDraft: Identifiable {
    let id = UUID()
    let category: ScreenshotCategoryRecord?
}

struct CategoryEditorView: View {
    static let availableSymbols = [
        "tray", "folder", "tag", "bookmark", "star", "heart",
        "cart", "book.closed", "calendar", "mappin.and.ellipse",
        "fork.knife", "checkmark.seal", "airplane", "quote.opening",
        "arrowshape.turn.up.right", "gift", "house", "briefcase",
        "graduationcap", "lightbulb", "music.note", "gamecontroller",
        "figure.run", "pawprint", "wrench.and.screwdriver", "ellipsis.circle"
    ]

    @Environment(\.dismiss) private var dismiss

    let category: ScreenshotCategoryRecord?
    let onSave: (String, String) throws -> Void

    @State private var name: String
    @State private var symbolName: String
    @State private var errorMessage: String?

    init(
        category: ScreenshotCategoryRecord?,
        onSave: @escaping (String, String) throws -> Void
    ) {
        self.category = category
        self.onSave = onSave
        _name = State(initialValue: category?.name ?? "")
        _symbolName = State(initialValue: category?.symbolName ?? "tag")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Category name", text: $name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .accessibilityIdentifier("category.name")
                }

                Section("Icon") {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 48), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(Self.availableSymbols, id: \.self) { symbol in
                            Button {
                                symbolName = symbol
                            } label: {
                                Image(systemName: symbol)
                                    .font(.title3)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        symbolName == symbol
                                            ? Color.accentColor.opacity(0.18)
                                            : Color.secondary.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 10)
                                    )
                                    .overlay {
                                        if symbolName == symbol {
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.accentColor, lineWidth: 2)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(symbolName == symbol ? Color.accentColor : Color.primary)
                            .accessibilityLabel(symbol.replacingOccurrences(of: ".", with: " "))
                            .accessibilityValue(symbolName == symbol ? "Selected" : "")
                        }
                    }
                    .padding(.vertical, 6)
                }

            }
            .navigationTitle(category == nil ? "New Category" : "Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            try onSave(name, symbolName)
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("category.save")
                }
            }
        }
        .presentationDetents([.large])
        .alert("Couldn't Save Category", isPresented: errorBinding) {
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
}

#Preview {
    CategoryEditorView(category: nil) { _, _ in }
}
