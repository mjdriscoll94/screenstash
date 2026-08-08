import Foundation

protocol CategorySuggesting: Sendable {
    func suggestCategory(for recognizedText: String) -> ScreenshotCategory
}

struct CategorySuggestionService: CategorySuggesting {
    private let keywordGroups: [(category: ScreenshotCategory, keywords: [String])] = [
        (.buyLater, ["price", "$", "add to cart", "buy now", "shipping", "sale", "discount"]),
        (.readLater, ["article", "newsletter", "read more", "minutes read", "author", "published"]),
        (.event, ["event", "appointment", "meeting", "starts at", "rsvp", "ticket", "calendar"]),
        (.address, ["street", "avenue", "road", "drive", "directions", "navigate", "zip code"]),
        (.recipe, ["recipe", "ingredients", "tablespoon", "teaspoon", "preheat", "serves", "bake"]),
        (.confirmation, ["confirmation", "order number", "booking", "receipt", "reference number", "reservation"]),
        (.travel, ["flight", "boarding", "departure", "arrival", "hotel", "gate", "itinerary"]),
        (.quote, ["quote", "said", "wisdom", "inspiration"]),
        (.followUp, ["follow up", "reply", "respond", "call back", "get back to", "reminder"])
    ]

    func suggestCategory(for recognizedText: String) -> ScreenshotCategory {
        let normalizedText = recognizedText.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )

        let scored = keywordGroups.map { group in
            let score = group.keywords.reduce(into: 0) { result, keyword in
                if normalizedText.localizedStandardContains(keyword) {
                    result += keyword.count
                }
            }
            return (category: group.category, score: score)
        }

        return scored.max { lhs, rhs in lhs.score < rhs.score }
            .flatMap { $0.score > 0 ? $0.category : nil } ?? .other
    }
}

