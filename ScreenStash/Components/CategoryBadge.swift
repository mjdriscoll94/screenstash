import SwiftUI

struct CategoryBadge: View {
    let name: String
    let symbolName: String

    var body: some View {
        Label(name, systemImage: symbolName)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .foregroundStyle(ScreenStashTheme.brandBlue)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(ScreenStashTheme.brandBlue.opacity(0.10), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(ScreenStashTheme.brandBlue.opacity(0.15), lineWidth: 1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Category: \(name)")
    }
}

#Preview {
    CategoryBadge(name: "Read Later", symbolName: "book.closed")
        .padding()
}
