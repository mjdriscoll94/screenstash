import SwiftUI

struct OnboardingView: View {
    fileprivate enum Page: Int, CaseIterable, Identifiable {
        case saveNew
        case importExisting
        case actAndClear

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .saveNew: "Save New Screenshots"
            case .importExisting: "Import Existing Screenshots"
            case .actAndClear: "Find It, Act, Clear It Out"
            }
        }

        var message: String {
            switch self {
            case .saveNew:
                "After taking a screenshot, tap Share and choose FrameFile. Add a title and category before saving it."
            case .importExisting:
                "Already have screenshots in Photos? Open the Inbox, tap the plus button, and choose one or more images to import."
            case .actAndClear:
                "Search recognized text, add reminders, and resolve finished items. After confirming the FrameFile copy is safe, delete the original from the screenshot preview or Photos."
            }
        }

        var guideImage: ScreenshotGuideImage {
            switch self {
            case .saveNew: .share
            case .importExisting: .importExisting
            case .actAndClear: .deleteOriginal
            }
        }
    }

    let showsSkip: Bool
    let onCompletion: () -> Void
    @State private var pageIndex: Int

    init(showsSkip: Bool = true, onCompletion: @escaping () -> Void) {
        self.showsSkip = showsSkip
        self.onCompletion = onCompletion

        // This launch argument makes every page independently screenshot-testable
        // without changing the normal first-launch experience.
        let pageArgument = ProcessInfo.processInfo.arguments
            .first { $0.hasPrefix("-onboarding-page=") }
        let requestedPage = pageArgument
            .flatMap { Int($0.replacingOccurrences(of: "-onboarding-page=", with: "")) }
        let safePage = min(max(requestedPage ?? 0, 0), Page.allCases.count - 1)
        _pageIndex = State(initialValue: safePage)
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsSkip {
                HStack {
                    Spacer()
                    Button("Skip", action: onCompletion)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .accessibilityHint("Closes the FrameFile guide")
                }
            }

            TabView(selection: $pageIndex) {
                ForEach(Page.allCases) { page in
                    OnboardingPageView(page: page)
                        .tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button {
                if pageIndex == Page.allCases.count - 1 {
                    onCompletion()
                } else {
                    withAnimation { pageIndex += 1 }
                }
            } label: {
                Text(pageIndex == Page.allCases.count - 1 ? (showsSkip ? "Get Started" : "Done") : "Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
            .accessibilityIdentifier("onboarding.continue")
        }
        .frameFileScreenBackground()
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingView.Page

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ScreenshotGuideImageView(kind: page.guideImage)
                    .frame(maxWidth: 350)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(page.guideImage.accessibilityLabel)
                    .accessibilityIdentifier(page.guideImage.accessibilityIdentifier)

                VStack(spacing: 10) {
                    Text(page.title)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    Text(page.message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(18)
                .frame(maxWidth: .infinity)
                .frameFileCard()
                .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity)
        }
    }
}

fileprivate enum ScreenshotGuideImage {
    case share
    case importExisting
    case deleteOriginal

    var aspectRatio: CGFloat {
        switch self {
        case .share, .importExisting, .deleteOriginal: 1.34
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .share:
            "Screenshot preview with the Share button highlighted in the upper-right corner."
        case .importExisting:
            "FrameFile Inbox with the centered plus button highlighted for importing existing screenshots."
        case .deleteOriginal:
            "Screenshot preview with the X button highlighted in the upper-left corner."
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .share: "onboarding.guide.share"
        case .importExisting: "onboarding.guide.importExisting"
        case .deleteOriginal: "onboarding.guide.deleteOriginal"
        }
    }
}

private struct ScreenshotGuideImageView: View {
    let kind: ScreenshotGuideImage

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                screenshot(in: geometry.size)
                overlay(in: geometry.size)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        }
        .aspectRatio(kind.aspectRatio, contentMode: .fit)
    }

    @ViewBuilder
    private func screenshot(in size: CGSize) -> some View {
        switch kind {
        case .share, .deleteOriginal:
            Image("TutorialScreenshotEditor")
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height, alignment: .top)
        case .importExisting:
            ExistingScreenshotImportGuide()
                .frame(width: size.width, height: size.height)
        }
    }

    @ViewBuilder
    private func overlay(in size: CGSize) -> some View {
        switch kind {
        case .share:
            targetRing(at: editorPoint(ScreenshotEditorGeometry.shareButtonCenter, in: size))
            GuideCallout(text: "Tap Share", arrow: "arrow.up.right")
                .position(x: size.width * 0.57, y: size.height * 0.60)
        case .deleteOriginal:
            targetRing(at: editorPoint(ScreenshotEditorGeometry.closeButtonCenter, in: size))
            GuideCallout(text: "Tap X", arrow: "arrow.up.left", arrowFirst: true)
                .position(x: size.width * 0.30, y: size.height * 0.60)
        case .importExisting:
            EmptyView()
        }
    }

    /// The tutorial image is rendered width-first and aligned to its top edge.
    /// Mapping source-image pixels through that same scale keeps each ring on
    /// the exact control center instead of relying on percentages of the crop.
    private func editorPoint(_ sourcePoint: CGPoint, in size: CGSize) -> CGPoint {
        let scale = size.width / ScreenshotEditorGeometry.sourceWidth
        return CGPoint(x: sourcePoint.x * scale, y: sourcePoint.y * scale)
    }

    private func targetRing(at point: CGPoint) -> some View {
        Circle()
            .fill(Color.accentColor.opacity(0.16))
            .frame(width: 54, height: 54)
            .overlay {
                Circle().stroke(Color.accentColor, lineWidth: 4)
            }
            .position(point)
    }
}

private enum ScreenshotEditorGeometry {
    static let sourceWidth: CGFloat = 1_206
    static let closeButtonCenter = CGPoint(x: 113, y: 246)
    static let shareButtonCenter = CGPoint(x: 916, y: 246)
}

private struct ExistingScreenshotImportGuide: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Inbox")
                        .font(.title2.bold())
                    Text("Bring in screenshots you already saved")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.16))
                        .frame(width: 62, height: 62)
                    Circle()
                        .stroke(Color.accentColor, lineWidth: 4)
                        .frame(width: 62, height: 62)
                    Circle()
                        .fill(.background)
                        .frame(width: 46, height: 46)
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .accessibilityHidden(true)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)

            Spacer(minLength: 10)

            HStack(spacing: 12) {
                importThumbnail(symbol: "photo", color: .blue)
                importThumbnail(symbol: "doc.text.image", color: .purple)
                importThumbnail(symbol: "map", color: .green)
            }

            Spacer(minLength: 10)

            GuideCallout(text: "Tap + to choose from Photos", arrow: "arrow.up")
                .padding(.bottom, 16)
        }
        .background(Color(uiColor: .systemBackground))
    }

    private func importThumbnail(symbol: String, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(color.opacity(0.12))
            .frame(width: 72, height: 82)
            .overlay {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(color)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(color.opacity(0.18), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

private struct GuideCallout: View {
    let text: String
    let arrow: String
    var arrowFirst = false

    var body: some View {
        HStack(spacing: 7) {
            if arrowFirst {
                Image(systemName: arrow)
            }
            Text(text)
                .font(.subheadline.bold())
            if !arrowFirst {
                Image(systemName: arrow)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.accentColor, in: Capsule())
        .shadow(color: .black.opacity(0.22), radius: 5, y: 2)
    }
}

struct HowToUseScreenStashView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        OnboardingView(showsSkip: false) {
            dismiss()
        }
        .navigationTitle("How to Use FrameFile")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    OnboardingView(onCompletion: {})
}
