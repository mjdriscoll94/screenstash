import XCTest
@testable import ScreenStash

final class ScreenshotGridLayoutTests: XCTestCase {
    func testTwoColumnsExactlyFitCommonIPhoneWidths() {
        for containerWidth in [320.0, 375.0, 402.0, 430.0] {
            let columnWidth = ScreenshotGridLayout.columnWidth(for: containerWidth)
            let occupiedWidth = (columnWidth * 2)
                + ScreenshotGridLayout.spacing
                + (ScreenshotGridLayout.horizontalPadding * 2)

            XCTAssertGreaterThan(columnWidth, 0)
            XCTAssertEqual(occupiedWidth, containerWidth, accuracy: 0.001)
        }
    }
}
