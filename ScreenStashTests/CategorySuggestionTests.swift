import XCTest
@testable import ScreenStash

final class CategorySuggestionTests: XCTestCase {
    private let service = CategorySuggestionService()

    func testSuggestsRecipeFromCookingTerms() {
        let result = service.suggestCategory(
            for: "Ingredients: 2 eggs and flour. Preheat the oven and bake for 20 minutes."
        )
        XCTAssertEqual(result, .recipe)
    }

    func testSuggestsConfirmationFromReferenceNumber() {
        let result = service.suggestCategory(
            for: "Booking confirmation. Your reference number is SS-4820."
        )
        XCTAssertEqual(result, .confirmation)
    }

    func testFallsBackToOtherWithoutMatchingKeywords() {
        XCTAssertEqual(service.suggestCategory(for: "A quiet blue square"), .other)
    }
}

