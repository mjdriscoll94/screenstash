import SwiftUI
import UIKit

enum ScreenStashTheme {
    static let cardCornerRadius: CGFloat = 20
    static let imageCornerRadius: CGFloat = 12
    static let compactSpacing: CGFloat = 8
    static let standardSpacing: CGFloat = 16

    static let brandBlue = Color(red: 0.08, green: 0.43, blue: 0.96)
    static let brandCyan = Color(red: 0.08, green: 0.78, blue: 0.88)

    static let cardBackground = adaptiveColor(
        light: UIColor(white: 1, alpha: 0.94),
        dark: UIColor(red: 0.09, green: 0.13, blue: 0.19, alpha: 0.96)
    )
    static let secondaryBackground = adaptiveColor(
        light: UIColor(red: 0.95, green: 0.98, blue: 1, alpha: 1),
        dark: UIColor(red: 0.035, green: 0.065, blue: 0.105, alpha: 1)
    )
    static let canvasBottom = adaptiveColor(
        light: UIColor(red: 0.92, green: 0.97, blue: 0.99, alpha: 1),
        dark: UIColor(red: 0.025, green: 0.045, blue: 0.075, alpha: 1)
    )
    static let cardStroke = adaptiveColor(
        light: UIColor(red: 0.33, green: 0.67, blue: 0.94, alpha: 0.18),
        dark: UIColor(red: 0.35, green: 0.72, blue: 1, alpha: 0.24)
    )
    static let navigationSurface = adaptiveColor(
        light: UIColor(red: 0.96, green: 0.985, blue: 1, alpha: 0.92),
        dark: UIColor(red: 0.045, green: 0.075, blue: 0.12, alpha: 0.94)
    )

    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [brandBlue, brandCyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private static func adaptiveColor(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

struct FrameFileScreenBackground: View {
    var body: some View {
        LinearGradient(
            colors: [ScreenStashTheme.secondaryBackground, ScreenStashTheme.canvasBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(ScreenStashTheme.brandCyan.opacity(0.13))
                .frame(width: 260, height: 260)
                .blur(radius: 42)
                .offset(x: 95, y: -125)
        }
        .accessibilityHidden(true)
    }
}

private struct FrameFileCardModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(ScreenStashTheme.cardBackground)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(ScreenStashTheme.cardStroke, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.07), radius: 12, y: 5)
    }
}

extension View {
    func frameFileCard(cornerRadius: CGFloat = ScreenStashTheme.cardCornerRadius) -> some View {
        modifier(FrameFileCardModifier(cornerRadius: cornerRadius))
    }

    func frameFileScreenBackground() -> some View {
        background {
            FrameFileScreenBackground()
                .ignoresSafeArea()
        }
    }
}

struct FrameFileGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                Capsule()
                    .fill(ScreenStashTheme.brandGradient)
                    .frame(width: 4, height: 20)
                    .accessibilityHidden(true)

                configuration.label
                    .font(.headline)
            }

            configuration.content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frameFileCard()
    }
}
