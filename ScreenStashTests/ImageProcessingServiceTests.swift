import UIKit
import XCTest
@testable import ScreenStash

final class ImageProcessingServiceTests: XCTestCase {
    func testInvalidDataReturnsUnreadableImageError() async {
        do {
            _ = try await ImageProcessingService().process(Data())
            XCTFail("Expected invalid image data to fail")
        } catch let error as ScreenStashServiceError {
            XCTAssertEqual(error, .unreadableImage)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testProcessingConstrainsFullImageAndThumbnailDimensions() async throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: 1_200, height: 2_400),
            format: format
        )
        let sourceData = renderer.jpegData(withCompressionQuality: 1) { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1_200, height: 2_400))
            UIColor.black.setFill()
            context.fill(CGRect(x: 80, y: 80, width: 1_040, height: 160))
        }
        let service = ImageProcessingService(
            maximumImageDimension: 600,
            thumbnailDimension: 120
        )

        let result = try await service.process(sourceData)
        let fullImage = try XCTUnwrap(UIImage(data: result.imageData))
        let thumbnail = try XCTUnwrap(UIImage(data: result.thumbnailData))

        XCTAssertLessThanOrEqual(max(fullImage.size.width, fullImage.size.height), 600)
        XCTAssertLessThanOrEqual(max(thumbnail.size.width, thumbnail.size.height), 120)
        XCTAssertGreaterThan(result.imageData.count, 0)
        XCTAssertGreaterThan(result.thumbnailData.count, 0)
    }
}
