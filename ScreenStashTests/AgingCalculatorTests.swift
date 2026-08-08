import Foundation
import XCTest
@testable import ScreenStash

final class AgingCalculatorTests: XCTestCase {
    func testBucketsAtThirtySixtyAndNinetyDays() {
        let now = Date(timeIntervalSince1970: 10_000_000)

        XCTAssertEqual(
            AgingCalculator.bucket(for: now.addingTimeInterval(-35 * 86_400), now: now),
            .thirtyDays
        )
        XCTAssertEqual(
            AgingCalculator.bucket(for: now.addingTimeInterval(-65 * 86_400), now: now),
            .sixtyDays
        )
        XCTAssertEqual(
            AgingCalculator.bucket(for: now.addingTimeInterval(-95 * 86_400), now: now),
            .ninetyDays
        )
    }

    func testKeepingScreenshotResetsItsReviewClock() {
        let now = Date(timeIntervalSince1970: 10_000_000)
        let item = ScreenshotItem(
            createdAt: now.addingTimeInterval(-100 * 86_400),
            imageData: Data([1]),
            status: .active,
            lastReviewedAt: now.addingTimeInterval(-5 * 86_400)
        )

        XCTAssertFalse(AgingCalculator.needsReview(item: item, thresholdDays: 30, now: now))
    }
}

