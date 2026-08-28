import SwiftUI

struct LoadingOverlay: View {
    let message: String

    var body: some View {
        VStack(spacing: ScreenStashTheme.compactSpacing) {
            ProgressView()
                .controlSize(.large)
                .tint(ScreenStashTheme.brandBlue)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: ScreenStashTheme.cardCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: ScreenStashTheme.cardCornerRadius)
                .stroke(ScreenStashTheme.cardStroke, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.10), radius: 16, y: 7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}
