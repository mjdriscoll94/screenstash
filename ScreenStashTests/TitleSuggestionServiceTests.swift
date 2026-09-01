import XCTest
@testable import ScreenStash

final class TitleSuggestionServiceTests: XCTestCase {
    private let service = TitleSuggestionService()

    func testPrefersProductHeadingOverStatusAndPriceText() {
        let text = """
        9:41 AM
        Safari
        Ergonomic Desk Lamp
        $79.00 free shipping
        Add to cart
        """

        XCTAssertEqual(service.suggestTitle(for: text), "Ergonomic Desk Lamp")
    }

    func testPrefersConciseHeadingOverLongBodyCopy() {
        let text = """
        Thank you for choosing to fly with us and please arrive at least two hours before departure.
        Flight to Chicago
        Departure 9:40 AM Gate C12
        """

        XCTAssertEqual(service.suggestTitle(for: text), "Flight to Chicago")
    }

    func testKeepsUsefulConfirmationHeading() {
        let text = """
        Order Confirmation
        Reference Number 82491
        Your order is being prepared.
        """

        XCTAssertEqual(service.suggestTitle(for: text), "Order Confirmation")
    }

    func testUsesReadableFallbackWhenOCRHasNoUsefulText() {
        XCTAssertEqual(service.suggestTitle(for: "9:41\n$12.00\n•••"), "Imported Screenshot")
    }

    func testLimitsLongTitlesAtAWordBoundary() {
        let title = service.suggestTitle(
            for: "A practical guide to organizing every screenshot you might want to reference again in the future"
        )

        XCTAssertLessThanOrEqual(title.count, 64)
        XCTAssertFalse(title.hasSuffix(" "))
    }
}
