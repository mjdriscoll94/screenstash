import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ProcessedScreenshot: Sendable {
    let imageData: Data
    let thumbnailData: Data
    let pixelWidth: Int
    let pixelHeight: Int
}

protocol ImageProcessing: Sendable {
    func process(_ sourceData: Data) async throws -> ProcessedScreenshot
}

struct ImageProcessingService: ImageProcessing {
    let maximumImageDimension: Int
    let thumbnailDimension: Int
    let imageQuality: CGFloat
    let thumbnailQuality: CGFloat

    init(
        maximumImageDimension: Int = 3_000,
        thumbnailDimension: Int = 480,
        imageQuality: CGFloat = 0.88,
        thumbnailQuality: CGFloat = 0.78
    ) {
        self.maximumImageDimension = maximumImageDimension
        self.thumbnailDimension = thumbnailDimension
        self.imageQuality = imageQuality
        self.thumbnailQuality = thumbnailQuality
    }

    func process(_ sourceData: Data) async throws -> ProcessedScreenshot {
        let maximumImageDimension = maximumImageDimension
        let thumbnailDimension = thumbnailDimension
        let imageQuality = imageQuality
        let thumbnailQuality = thumbnailQuality

        return try await Task.detached(priority: .userInitiated) {
            guard !sourceData.isEmpty else {
                throw ScreenStashServiceError.unreadableImage
            }

            guard let source = CGImageSourceCreateWithData(sourceData as CFData, nil) else {
                throw ScreenStashServiceError.unreadableImage
            }

            guard
                let fullImage = Self.makeThumbnail(from: source, maximumDimension: maximumImageDimension),
                let thumbnail = Self.makeThumbnail(from: source, maximumDimension: thumbnailDimension)
            else {
                throw ScreenStashServiceError.unreadableImage
            }

            let fullData = try Self.jpegData(from: fullImage, quality: imageQuality)
            let thumbnailData = try Self.jpegData(from: thumbnail, quality: thumbnailQuality)

            return ProcessedScreenshot(
                imageData: fullData,
                thumbnailData: thumbnailData,
                pixelWidth: fullImage.width,
                pixelHeight: fullImage.height
            )
        }.value
    }

    private static func makeThumbnail(
        from source: CGImageSource,
        maximumDimension: Int
    ) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumDimension
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func jpegData(from image: CGImage, quality: CGFloat) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw ScreenStashServiceError.imageEncodingFailed
        }

        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ScreenStashServiceError.imageEncodingFailed
        }
        return data as Data
    }
}
