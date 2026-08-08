import Foundation
import XCTest
@testable import ScreenStash

@MainActor
final class SearchFilteringTests: XCTestCase {
    func testSearchMatchesRecognizedTextAndReportsReason() {
        let category = ScreenshotCategoryRecord(category: .travel, sortOrder: 0)
        let item = ScreenshotItem(
            imageData: Data([1]),
            recognizedText: "Departure from Gate C12",
            title: "Trip",
            category: category,
            status: .active
        )
        let viewModel = SearchViewModel()
        viewModel.query = "gate c12"

        XCTAssertEqual(viewModel.results(from: [item]).count, 1)
        XCTAssertEqual(viewModel.matchReason(for: item), .recognizedText)
    }

    func testStatusAndFavoritesFiltersCombine() {
        let favorite = ScreenshotItem(
            imageData: Data([1]),
            title: "Favorite",
            status: .resolved,
            isFavorite: true
        )
        let other = ScreenshotItem(
            imageData: Data([2]),
            title: "Other",
            status: .resolved
        )
        let viewModel = SearchViewModel()
        viewModel.status = .resolved
        viewModel.favoritesOnly = true

        XCTAssertEqual(
            viewModel.results(from: [favorite, other]).map(\.id),
            [favorite.id]
        )
    }

    func testResolvedItemsStayOutOfDefaultSearchButCanBeFilteredExplicitly() {
        let item = ScreenshotItem(
            imageData: Data([1]),
            recognizedText: "Warranty receipt",
            title: "Receipt",
            status: .resolved
        )
        let viewModel = SearchViewModel()
        viewModel.query = "receipt"

        XCTAssertTrue(viewModel.results(from: [item]).isEmpty)

        viewModel.status = .resolved
        XCTAssertEqual(viewModel.results(from: [item]).map(\.id), [item.id])
    }
}
