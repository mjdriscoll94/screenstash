import SwiftUI

enum ScreenshotGridLayout {
    static let horizontalPadding: CGFloat = 16
    static let spacing: CGFloat = 12

    /// Returns an exact two-column width so unusually wide image content can
    /// never participate in grid sizing or extend beyond the safe container.
    static func columnWidth(for containerWidth: CGFloat) -> CGFloat {
        let contentWidth = containerWidth - (horizontalPadding * 2) - spacing
        return max(1, contentWidth / 2)
    }

    static func columns(columnWidth: CGFloat) -> [GridItem] {
        [
            GridItem(.fixed(columnWidth), spacing: spacing, alignment: .top),
            GridItem(.fixed(columnWidth), spacing: 0, alignment: .top)
        ]
    }
}

struct ScreenshotCard: View {
    let item: ScreenshotItem

    var body: some View {
        VStack(alignment: .leading, spacing: ScreenStashTheme.compactSpacing) {
            // Use a layout-neutral viewport so the source image's aspect ratio
            // can never widen its grid column. The image fills and crops only
            // inside this consistent portrait preview frame.
            Color.clear
                .aspectRatio(0.78, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay {
                    ScreenshotThumbnail(data: item.thumbnailData)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
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
        .accessibilityIdentifier("screenshot.card.\(item.id.uuidString.lowercased())")
    }
}
