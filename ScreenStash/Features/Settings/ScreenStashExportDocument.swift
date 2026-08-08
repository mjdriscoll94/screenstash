import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let screenStashExport = UTType(
        exportedAs: "com.screenstash.export",
        conformingTo: .package
    )
}

struct ScreenStashExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.screenStashExport] }

    private let payload: ScreenStashExportPayload

    init(payload: ScreenStashExportPayload = ScreenStashExportPayload(
        metadata: Data("{\"screenshots\":[]}".utf8),
        images: [:],
        recognizedTextFiles: [:]
    )) {
        self.payload = payload
    }

    init(configuration: ReadConfiguration) throws {
        guard let metadataWrapper = configuration.file.fileWrappers?["metadata.json"],
              let metadata = metadataWrapper.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        payload = ScreenStashExportPayload(
            metadata: metadata,
            images: [:],
            recognizedTextFiles: [:]
        )
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let metadataWrapper = FileWrapper(regularFileWithContents: payload.metadata)
        metadataWrapper.preferredFilename = "metadata.json"

        let imageWrappers = payload.images.mapValues { FileWrapper(regularFileWithContents: $0) }
        let imagesDirectory = FileWrapper(directoryWithFileWrappers: imageWrappers)
        imagesDirectory.preferredFilename = "images"

        let textWrappers = payload.recognizedTextFiles.mapValues { FileWrapper(regularFileWithContents: $0) }
        let textDirectory = FileWrapper(directoryWithFileWrappers: textWrappers)
        textDirectory.preferredFilename = "ocr"

        return FileWrapper(directoryWithFileWrappers: [
            "metadata.json": metadataWrapper,
            "images": imagesDirectory,
            "ocr": textDirectory
        ])
    }
}

