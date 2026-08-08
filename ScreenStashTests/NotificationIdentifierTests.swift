import Foundation
import XCTest
@testable import ScreenStash

final class NotificationIdentifierTests: XCTestCase {
    func testIdentifierIsStableAndNamespaced() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000042") ?? UUID()

        XCTAssertEqual(
            NotificationService.identifier(for: id),
            "screenstash.reminder.00000000-0000-0000-0000-000000000042"
        )
    }
}

