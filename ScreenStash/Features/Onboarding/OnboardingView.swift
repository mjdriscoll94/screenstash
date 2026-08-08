import SwiftUI

struct OnboardingView: View {
    fileprivate enum Page: Int, CaseIterable, Identifiable {
        case share
        case add
        case deleteOriginal

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .share: "Share Before Saving"
            case .add: "Choose Where It Belongs"
            case .deleteOriginal: "Delete the Original"
            }
        }

        var message: String {
            switch self {
            case .share:
                "After taking a screenshot, tap Share and choose ScreenStash. If it is hidden, tap More once to enable it."
            case .add:
                "Pick a category, then tap Add to ScreenStash. Wait for the share action to finish before continuing."
            case .deleteOriginal:
                "Back in the screenshot preview, tap X and choose Delete Screenshot. Your searchable copy is already safe in ScreenStash."
            }
        }

        var guideImage: ScreenshotGuideImage {
            switch self {
            case .share: .share
            case .add: .add
            case .deleteOriginal: .deleteOriginal
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
                        .accessibilityHint("Closes the ScreenStash guide")
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
        .background(ScreenStashTheme.secondaryBackground)
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
    case add
    case deleteOriginal

    var aspectRatio: CGFloat {
        switch self {
        case .share, .deleteOriginal: 1.34
        case .add: 0.98
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .share:
            "Screenshot preview with the Share button highlighted in the upper-right corner."
        case .add:
            "ScreenStash share screen with Category first and Add to ScreenStash second."
        case .deleteOriginal:
            "Screenshot preview with the X button highlighted in the upper-left corner."
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .share: "onboarding.guide.share"
        case .add: "onboarding.guide.add"
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
        case .add:
            Image("TutorialAddToScreenStash")
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height, alignment: .top)
                .offset(y: -size.width * 0.94)
        }
    }

    @ViewBuilder
    private func overlay(in size: CGSize) -> some View {
        switch kind {
        case .share:
            targetRing(at: CGPoint(x: size.width * 0.76, y: size.height * 0.28))
            GuideCallout(text: "Tap Share", arrow: "arrow.up.right")
                .position(x: size.width * 0.57, y: size.height * 0.60)
        case .deleteOriginal:
            targetRing(at: CGPoint(x: size.width * 0.09, y: size.height * 0.28))
            GuideCallout(text: "Tap X", arrow: "arrow.up.left", arrowFirst: true)
                .position(x: size.width * 0.30, y: size.height * 0.60)
        case .add:
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.accentColor, lineWidth: 4)
                .frame(width: size.width * 0.88, height: 56)
                .position(x: size.width * 0.5, y: size.height * 0.39)
            GuideCallout(text: "1  Choose a category", arrow: "arrow.down")
                .position(x: size.width * 0.5, y: size.height * 0.19)

            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.accentColor, lineWidth: 4)
                .frame(width: size.width * 0.88, height: 56)
                .position(x: size.width * 0.5, y: size.height * 0.66)
            GuideCallout(text: "2  Tap Add", arrow: "arrow.up")
                .position(x: size.width * 0.5, y: size.height * 0.86)
        }
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
        .navigationTitle("How to Use ScreenStash")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    OnboardingView(onCompletion: {})
}
