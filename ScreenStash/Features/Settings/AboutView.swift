import SwiftUI

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 14) {
                    Image("LaunchLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                        .accessibilityHidden(true)
                    Text(AppBrand.storeName)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text("A calm, private inbox for the screenshots you want to act on.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
                .accessibilityElement(children: .combine)
            }

            Section("Details") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Build", value: buildNumber)
                LabeledContent("Storage", value: "On device")
                LabeledContent("Text recognition", value: "On device")
            }

            Section("Learn More") {
                NavigationLink("Privacy") {
                    PrivacyView()
                }

                NavigationLink("How to Use ScreenStash") {
                    HowToUseScreenStashView()
                }
            }

            Section("Support") {
                if let supportWebsiteURL = AppLinks.supportWebsiteURL {
                    Link(destination: supportWebsiteURL) {
                        Label("Support Website", systemImage: "safari")
                    }
                    .accessibilityHint("Opens the ScreenStash support website")
                }

                if let supportEmailURL = AppLinks.supportEmailURL(subject: "ScreenStash Support") {
                    Link(destination: supportEmailURL) {
                        Label("Email Support", systemImage: "envelope")
                    }
                    .accessibilityHint("Opens a new email to mjddevtools@gmail.com")
                }

                LabeledContent("Email", value: AppLinks.supportEmailAddress)
                    .textSelection(.enabled)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

}
