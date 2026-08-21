import SwiftUI

struct ScreenshotCard: View {
    let item: ScreenshotItem

    var body: some View {
        VStack(alignment: .leading, spacing: ScreenStashTheme.compactSpacing) {
            ScreenshotThumbnail(data: item.thumbnailData)
                .aspectRatio(0.78, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: ScreenStashTheme.imageCornerRadius))

            Text(item.displayTitle)
                .font(.headline)
                .lineLimit(2)

            if let category = item.category {
                CategoryBadge(name: category.name, symbolName: category.symbolName)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipped()
            }

            HStack(spacing: ScreenStashTheme.compactSpacing) {
                Text(item.importedAt, format: .relative(presentation: .named))
                Spacer(minLength: 0)
                if item.reminderDate != nil {
                    Image(systemName: "bell.fill")
                        .accessibilityLabel("Has reminder")
                }
                if item.isFavorite {
                    Image(systemName: "star.fill")
                        .accessibilityLabel("Favorite")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ScreenStashTheme.cardBackground, in: RoundedRectangle(cornerRadius: ScreenStashTheme.cardCornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.displayTitle)
        .accessibilityValue(item.category?.name ?? "Unsorted")
    }
}
