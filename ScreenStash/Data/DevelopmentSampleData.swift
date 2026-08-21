import Foundation
import SwiftData
import UIKit

@MainActor
enum DevelopmentSampleData {
    static func seedIfRequested(in context: ModelContext) {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-seed-sample-data") else { return }

        if arguments.contains("-reset-data"),
           let existing = try? context.fetch(FetchDescriptor<ScreenshotItem>()) {
            DeletedBuiltInCategoryStore.reset()
            existing.forEach(context.delete)

            if let categories = try? context.fetch(FetchDescriptor<ScreenshotCategoryRecord>()) {
                let existingKeys = Set(categories.map(\.key))
                for category in categories {
                    if let builtIn = category.builtInCategory {
                        category.name = builtIn.displayName
                        category.symbolName = builtIn.symbolName
                    } else {
                        context.delete(category)
                    }
                }

                for (index, builtIn) in ScreenshotCategory.allCases.enumerated()
                    where !existingKeys.contains(builtIn.rawValue) {
                    context.insert(ScreenshotCategoryRecord(category: builtIn, sortOrder: index))
                }
            }
            try? context.save()
        }

        let existingCount = (try? context.fetchCount(FetchDescriptor<ScreenshotItem>())) ?? 0
        guard existingCount == 0 else { return }

        let categories = (try? context.fetch(FetchDescriptor<ScreenshotCategoryRecord>())) ?? []
        let byKey = Dictionary(uniqueKeysWithValues: categories.map { ($0.key, $0) })
        let now = Date.now

        let samples: [Sample] = [
            Sample(
                id: stableID("00000000-0000-0000-0000-000000000001"),
                title: "Weekend Pancakes",
                subtitle: "Flour • eggs • milk • bake 20 min",
                category: .recipe,
                status: .active,
                ageInDays: 42,
                imageSize: CGSize(width: 600, height: 1_000),
                recognizedText: "Weekend Pancakes Recipe\n2 cups flour\n2 eggs\n1 cup milk\nBake for 20 minutes"
            ),
            Sample(
                id: stableID("00000000-0000-0000-0000-000000000002"),
                title: "Flight to Chicago",
                subtitle: "Departure 9:40 AM • Gate C12",
                category: .travel,
                status: .active,
                ageInDays: 8,
                imageSize: CGSize(width: 1_200, height: 600),
                recognizedText: "Flight 482\nDeparture 9:40 AM\nGate C12\nChicago",
                reminderDate: now.addingTimeInterval(2 * 86_400)
            ),
            Sample(
                id: stableID("00000000-0000-0000-0000-000000000003"),
                title: "Ergonomic Desk Lamp",
                subtitle: "$79 • free shipping",
                category: .buyLater,
                status: .inbox,
                ageInDays: 3,
                imageSize: CGSize(width: 800, height: 800),
                recognizedText: "Ergonomic Desk Lamp\n$79\nAdd to cart\nFree shipping",
                isFavorite: true
            ),
            Sample(
                id: stableID("00000000-0000-0000-0000-000000000004"),
                title: "Essay to Read",
                subtitle: "A short article about attention",
                category: .readLater,
                status: .resolved,
                ageInDays: 18,
                imageSize: CGSize(width: 480, height: 1_600),
                recognizedText: "An essay about attention\n8 minute read\nPublished Tuesday"
            ),
            Sample(
                id: stableID("00000000-0000-0000-0000-000000000005"),
                title: "Hotel Confirmation",
                subtitle: "Reference SS-10482",
                category: .confirmation,
                status: .archived,
                ageInDays: 95,
                imageSize: CGSize(width: 600, height: 1_000),
                recognizedText: "Hotel confirmation\nReference SS-10482\nCheck-in Friday"
            ),
            Sample(
                id: stableID("00000000-0000-0000-0000-000000000006"),
                title: "Follow Up with Alex",
                subtitle: "Send the revised notes",
                category: .followUp,
                status: .active,
                ageInDays: 65,
                imageSize: CGSize(width: 900, height: 500),
                recognizedText: "Please follow up with the revised notes next week"
            )
        ]

        for sample in samples {
            let imageData = makeImage(
                title: sample.title,
                subtitle: sample.subtitle,
                size: sample.imageSize
            )
            let item = ScreenshotItem(
                id: sample.id,
                createdAt: now.addingTimeInterval(-Double(sample.ageInDays) * 86_400),
                importedAt: now.addingTimeInterval(-Double(min(sample.ageInDays, 12)) * 86_400),
                updatedAt: now,
                imageData: imageData,
                thumbnailData: imageData,
                recognizedText: sample.recognizedText,
                title: sample.title,
                notes: "Development-only sample record.",
                category: byKey[sample.category.rawValue],
                status: sample.status,
                reminderDate: sample.reminderDate,
                isFavorite: sample.isFavorite,
                resolvedAt: sample.status == .resolved ? now : nil,
                isReviewed: true
            )
            context.insert(item)
        }

        try? context.save()
        #endif
    }

    #if DEBUG
    private struct Sample {
        let id: UUID
        let title: String
        let subtitle: String
        let category: ScreenshotCategory
        let status: ScreenshotStatus
        let ageInDays: Int
        let imageSize: CGSize
        let recognizedText: String
        var reminderDate: Date?
        var isFavorite = false
    }

    private static func stableID(_ value: String) -> UUID {
        UUID(uuidString: value) ?? UUID()
    }

    private static func makeImage(title: String, subtitle: String, size: CGSize) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.jpegData(withCompressionQuality: 0.86) { context in
            UIColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let horizontalInset = max(24, size.width * 0.08)
            let contentWidth = max(1, size.width - (horizontalInset * 2))
            let verticalScale = size.height / 1_000
            let textScale = max(0.55, min(size.width / 600, verticalScale))

            UIColor.systemIndigo.setFill()
            context.cgContext.fillEllipse(
                in: CGRect(
                    x: horizontalInset,
                    y: 62 * verticalScale,
                    width: 72 * textScale,
                    height: 72 * textScale
                )
            )

            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byWordWrapping

            NSString(string: title).draw(
                in: CGRect(
                    x: horizontalInset,
                    y: 180 * verticalScale,
                    width: contentWidth,
                    height: 180 * verticalScale
                ),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 42 * textScale, weight: .bold),
                    .foregroundColor: UIColor.label,
                    .paragraphStyle: paragraph
                ]
            )
            NSString(string: subtitle).draw(
                in: CGRect(
                    x: horizontalInset,
                    y: 370 * verticalScale,
                    width: contentWidth,
                    height: 140 * verticalScale
                ),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 26 * textScale),
                    .foregroundColor: UIColor.secondaryLabel,
                    .paragraphStyle: paragraph
                ]
            )

            UIColor.secondarySystemFill.setFill()
            context.cgContext.fill(
                CGRect(x: horizontalInset, y: 560 * verticalScale, width: contentWidth, height: 22 * textScale)
            )
            context.cgContext.fill(
                CGRect(x: horizontalInset, y: 610 * verticalScale, width: contentWidth * 0.83, height: 22 * textScale)
            )
            context.cgContext.fill(
                CGRect(x: horizontalInset, y: 660 * verticalScale, width: contentWidth * 0.93, height: 22 * textScale)
            )
        }
    }
    #endif
}
