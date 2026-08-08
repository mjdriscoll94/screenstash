import SwiftUI

struct ImportProgressView: View {
    let completedCount: Int
    let totalCount: Int
    let message: String
    let progress: Double

    var body: some View {
        VStack(spacing: 14) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("\(completedCount) of \(totalCount)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 18, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Importing screenshots. \(completedCount) of \(totalCount). \(message)")
    }
}

