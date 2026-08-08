import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct ShareableScreenshot: Transferable, Sendable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .jpeg) { screenshot in
            screenshot.data
        }
        .suggestedFileName("ScreenStash Screenshot.jpg")
    }
}

