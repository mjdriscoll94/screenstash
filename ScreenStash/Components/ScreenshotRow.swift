import SwiftUI

struct ScreenshotRow: View {
    let item: ScreenshotItem

    var body: some View {
        HStack(spacing: 12) {
            ScreenshotThumbnail(data: item.thumbnailData)
                .frame(width: 64, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 5) {
                Text(item.displayTitle)
                    .font(.headline)
                    .lineLimit(2)

                if let category = item.category {
                    Label(category.name, systemImage: category.symbolName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(item.importedAt, format: .dateTime.month(.abbreviated).day().year())
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            if item.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityLabel("Favorite")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.displayTitle)
        .accessibilityValue(item.category?.name ?? "Unsorted")
    }
}
