import SwiftUI
import UIKit

struct ZoomableImageView: View {
    let imageData: Data

    @State private var scale: CGFloat = 1
    @State private var settledScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var settledOffset: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                Color.black.opacity(0.04)

                if let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(magnificationGesture)
                        .simultaneousGesture(dragGesture)
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(response: 0.3)) {
                                if scale > 1 {
                                    resetZoom()
                                } else {
                                    scale = 2
                                    settledScale = 2
                                }
                            }
                        }
                        .accessibilityLabel("Full screenshot")
                        .accessibilityHint("Pinch or double tap to zoom")
                        .accessibilityAdjustableAction { direction in
                            switch direction {
                            case .increment:
                                setScale(min(scale + 0.5, 5))
                            case .decrement:
                                setScale(max(scale - 0.5, 1))
                            @unknown default:
                                break
                            }
                        }
                } else {
                    ErrorStateView(
                        title: "Image Unavailable",
                        message: "ScreenStash couldn't display this screenshot."
                    )
                }

                if scale > 1 {
                    Button {
                        withAnimation { resetZoom() }
                    } label: {
                        Label("Reset Zoom", systemImage: "arrow.counterclockwise")
                            .labelStyle(.iconOnly)
                            .padding(10)
                            .background(.regularMaterial, in: Circle())
                    }
                    .padding()
                    .accessibilityLabel("Reset zoom")
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: ScreenStashTheme.imageCornerRadius))
        }
    }

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(max(settledScale * value.magnification, 1), 5)
            }
            .onEnded { _ in
                settledScale = scale
                if scale == 1 {
                    offset = .zero
                    settledOffset = .zero
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(
                    width: settledOffset.width + value.translation.width,
                    height: settledOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                settledOffset = offset
            }
    }

    private func setScale(_ newScale: CGFloat) {
        withAnimation {
            scale = newScale
            settledScale = newScale
            if newScale == 1 {
                offset = .zero
                settledOffset = .zero
            }
        }
    }

    private func resetZoom() {
        scale = 1
        settledScale = 1
        offset = .zero
        settledOffset = .zero
    }
}

