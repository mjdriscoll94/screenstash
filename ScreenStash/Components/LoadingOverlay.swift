import SwiftUI

struct LoadingOverlay: View {
    let message: String

    var body: some View {
        VStack(spacing: ScreenStashTheme.compactSpacing) {
            ProgressView()
                .controlSize(.large)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: ScreenStashTheme.cardCornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

