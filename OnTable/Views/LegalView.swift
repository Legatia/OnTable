import SwiftUI

enum LegalDocumentType {
    case privacyPolicy
    case termsOfService

    var title: String {
        switch self {
        case .privacyPolicy: return "Privacy Policy"
        case .termsOfService: return "Terms of Service"
        }
    }
}

struct LegalView: View {
    let documentType: LegalDocumentType
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Last updated: January 2025")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    switch documentType {
                    case .privacyPolicy:
                        privacyPolicyContent
                    case .termsOfService:
                        termsOfServiceContent
                    }
                }
                .padding()
            }
            .navigationTitle(documentType.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Privacy Policy

    private var privacyPolicyContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            section(title: "Overview") {
                Text("OnTable (\"we\", \"our\", or \"us\") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, and safeguard your information when you use our mobile application.")
            }

            section(title: "Information We Collect") {
                bulletPoint("Decision data you create (titles, options, pros, cons)")
                bulletPoint("Subscription and purchase information")
                bulletPoint("Device information for app functionality")
            }

            section(title: "How We Use Your Information") {
                bulletPoint("To provide and maintain the app's core functionality")
                bulletPoint("To process your subscription payments")
                bulletPoint("To improve and personalize your experience")
            }

            section(title: "AI Feature Data Disclosure") {
                Text("When you use the AI Companion feature (Premium), your decision content (titles, options, and pros/cons) is sent to Groq, our AI provider, to generate suggestions. This data is used only to process your request and is not stored by Groq after the response is generated.")
                    .foregroundColor(.secondary)
            }

            section(title: "Data Storage") {
                Text("Your decision data is stored locally on your device. We do not have access to your decisions unless you explicitly choose to use features that require data transmission (like the AI Companion).")
                    .foregroundColor(.secondary)
            }

            section(title: "Third-Party Services") {
                bulletPoint("Apple (App Store, StoreKit for subscriptions)")
                bulletPoint("Groq (AI suggestions - Premium feature only)")
            }

            section(title: "Your Rights") {
                Text("You can delete all your data at any time by uninstalling the app. Your local decision data is not backed up to our servers.")
                    .foregroundColor(.secondary)
            }

            section(title: "Contact Us") {
                Text("If you have questions about this Privacy Policy, please contact us at support@ontable.app")
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Terms of Service

    private var termsOfServiceContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            section(title: "Agreement to Terms") {
                Text("By accessing or using OnTable, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the app.")
            }

            section(title: "Use of the App") {
                bulletPoint("You must be at least 13 years old to use this app")
                bulletPoint("You are responsible for maintaining the security of your device")
                bulletPoint("You agree not to misuse the app or help anyone else do so")
            }

            section(title: "Subscriptions") {
                bulletPoint("Some features require a paid subscription (Starter or Premium)")
                bulletPoint("Subscriptions automatically renew unless cancelled")
                bulletPoint("You can manage subscriptions in your Apple ID settings")
                bulletPoint("Refunds are handled according to Apple's policies")
            }

            section(title: "AI Features") {
                Text("The AI Companion feature provides suggestions based on your input. These suggestions are for informational purposes only and should not be considered professional advice. You are solely responsible for your decisions.")
                    .foregroundColor(.secondary)
            }

            section(title: "Intellectual Property") {
                Text("OnTable and its original content, features, and functionality are owned by us and are protected by international copyright, trademark, and other intellectual property laws.")
                    .foregroundColor(.secondary)
            }

            section(title: "Limitation of Liability") {
                Text("OnTable is provided \"as is\" without warranties of any kind. We are not liable for any decisions you make based on using the app or its features.")
                    .foregroundColor(.secondary)
            }

            section(title: "Changes to Terms") {
                Text("We reserve the right to modify these terms at any time. Continued use of the app after changes constitutes acceptance of the new terms.")
                    .foregroundColor(.secondary)
            }

            section(title: "Contact") {
                Text("For questions about these Terms, contact us at support@ontable.app")
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func section(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.secondary)
            Text(text)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

struct LegalView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LegalView(documentType: .privacyPolicy)
            LegalView(documentType: .termsOfService)
        }
    }
}
