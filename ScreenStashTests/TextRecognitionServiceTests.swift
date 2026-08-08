import XCTest
@testable import ScreenStash

final class TextRecognitionServiceTests: XCTestCase {
    func testEmptyImageDataProducesReadableError() async {
        let service = TextRecognitionService()

        do {
            _ = try await service.recognizeText(in: Data())
            XCTFail("Expected empty image data to fail")
        } catch let error as ScreenStashServiceError {
            XCTAssertEqual(error, .unreadableImage)
            XCTAssertNotNil(error.errorDescription)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}

