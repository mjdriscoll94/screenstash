import SwiftUI

struct PrivacyView: View {
    var body: some View {
        List {
            PrivacyRow(
                title: "Stored on your device",
                message: "Imported screenshots stay in local app storage. Share-sheet imports are staged only in FrameFile's private App Group.",
                symbol: "iphone"
            )
            PrivacyRow(
                title: "On-device text recognition",
                message: "Text is recognized with Apple's Vision framework and is not uploaded for processing.",
                symbol: "text.viewfinder"
            )
            PrivacyRow(
                title: "No account",
                message: "FrameFile does not require registration, a subscription, or a backend service.",
                symbol: "person.crop.circle.badge.checkmark"
            )
            PrivacyRow(
                title: "No tracking",
                message: "The app contains no advertising, analytics, or external tracking SDKs.",
                symbol: "hand.raised"
            )

            PrivacyRow(
                title: "You control retention",
                message: "Delete individual screenshots at any time, or use Delete All App Data in Settings. Deleting FrameFile data does not delete the original from Photos.",
                symbol: "trash"
            )

            Section("More Information") {
                Text("Your device backups are controlled by your iOS and iCloud settings. FrameFile itself does not upload screenshot content.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let privacyPolicyURL = AppLinks.privacyPolicyURL {
                    Link(destination: privacyPolicyURL) {
                        Label("Full Privacy Policy", systemImage: "safari")
                    }
                    .accessibilityHint("Opens the FrameFile privacy policy website")
                }

                if let supportEmailURL = AppLinks.supportEmailURL(subject: "FrameFile Privacy") {
                    Link(destination: supportEmailURL) {
                        Label("Privacy Questions", systemImage: "envelope")
                    }
                    .accessibilityHint("Opens a new email to mjddevtools@gmail.com")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .frameFileScreenBackground()
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrivacyRow: View {
    let title: String
    let message: String
    let symbol: String

    var body: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(ScreenStashTheme.brandGradient)
                        .frame(width: 36, height: 36)
                    Image(systemName: symbol)
                        .foregroundStyle(.white)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}
