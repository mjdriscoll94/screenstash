import SwiftUI
import UIKit

struct ScreenshotThumbnail: View {
    let data: Data?

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(uiColor: .tertiarySystemFill)
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .clipped()
        .accessibilityLabel(data == nil ? "Screenshot preview unavailable" : "Screenshot preview")
    }
}

