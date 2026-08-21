import SwiftUI

struct CategoryBadge: View {
    let name: String
    let symbolName: String

    var body: some View {
        Label(name, systemImage: symbolName)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.thinMaterial, in: Capsule())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Category: \(name)")
    }
}

#Preview {
    CategoryBadge(name: "Read Later", symbolName: "book.closed")
        .padding()
}
