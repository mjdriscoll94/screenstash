import Foundation
import Vision

protocol TextRecognizing: Sendable {
    func recognizeText(in imageData: Data) async throws -> String
}

struct TextRecognitionService: TextRecognizing {
    func recognizeText(in imageData: Data) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            guard !imageData.isEmpty else {
                throw ScreenStashServiceError.unreadableImage
            }

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(data: imageData, options: [:])
            do {
                try handler.perform([request])
            } catch {
                throw ScreenStashServiceError.textRecognitionFailed(error.localizedDescription)
            }

            return request.results?
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n") ?? ""
        }.value
    }
}

