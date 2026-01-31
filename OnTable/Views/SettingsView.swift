import SwiftUI

struct SettingsView: View {
    @ObservedObject var premiumManager = PremiumManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showingPaywall = false

    var body: some View {
        NavigationView {
            List {
                // Subscription Section
                Section {
                    subscriptionCard
                } header: {
                    Text("Subscription")
                }

                // Features Section
                Section {
                    featureRow(
                        icon: "square.grid.2x2",
                        title: "Options",
                        value: premiumManager.features.maxOptions == 99 ? "Unlimited" : "\(premiumManager.features.maxOptions) max"
                    )

                    featureRow(
                        icon: "square.and.arrow.up",
                        title: "Share to Social",
                        available: premiumManager.features.canShare
                    )

                    featureRow(
                        icon: "person.2",
                        title: "Host Rooms",
                        available: premiumManager.features.canHostRoom
                    )

                    featureRow(
                        icon: "checkmark.seal",
                        title: "Watermark-free",
                        available: !premiumManager.features.hasWatermark
                    )

                    featureRow(
                        icon: "slider.horizontal.3",
                        title: "Priority Weights",
                        available: premiumManager.features.hasPriorityWeights
                    )

                    featureRow(
                        icon: "doc.text",
                        title: "Decision Templates",
                        available: premiumManager.features.hasDecisionTemplates
                    )

                    featureRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Outcome Tracking",
                        available: premiumManager.features.hasOutcomeTracking
                    )

                    featureRow(
                        icon: "sparkles",
                        title: "AI Companion",
                        available: premiumManager.features.hasAICompanion
                    )
                } header: {
                    Text("Your Features")
                }

                // About Section
                Section {
                    Link(destination: URL(string: "https://ontable.app/terms")!) {
                        Label("Terms of Use", systemImage: "doc.text")
                    }

                    Link(destination: URL(string: "https://ontable.app/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }

                    Button(action: restorePurchases) {
                        Label("Restore Purchases", systemImage: "arrow.clockwise")
                    }
                } header: {
                    Text("About")
                }

                // Debug Section (only in DEBUG)
                #if DEBUG
                Section {
                    ForEach(SubscriptionTier.allCases, id: \.self) { tier in
                        Button(action: { premiumManager.setTierForTesting(tier) }) {
                            HStack {
                                Text("Set \(tier.displayName)")
                                Spacer()
                                if premiumManager.currentTier == tier {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Debug")
                }
                #endif
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Subscription Card

    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(premiumManager.currentTier.displayName)
                        .font(.headline)

                    Text(premiumManager.currentTier.monthlyPrice)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                tierBadge
            }

            if premiumManager.currentTier != .premium {
                Button(action: { showingPaywall = true }) {
                    Text(premiumManager.currentTier == .free ? "Upgrade Now" : "Upgrade to Premium")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.accentColor)
                        .cornerRadius(8)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var tierBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: tierIcon)
                .font(.caption)
            Text(premiumManager.currentTier.displayName)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(tierColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tierColor.opacity(0.15))
        .cornerRadius(8)
    }

    private var tierIcon: String {
        switch premiumManager.currentTier {
        case .free: return "person"
        case .starter: return "star"
        case .premium: return "crown.fill"
        }
    }

    private var tierColor: Color {
        switch premiumManager.currentTier {
        case .free: return .secondary
        case .starter: return .blue
        case .premium: return .purple
        }
    }

    // MARK: - Feature Rows

    private func featureRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }

    private func featureRow(icon: String, title: String, available: Bool) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(available ? .green : .secondary.opacity(0.5))
        }
    }

    // MARK: - Actions

    private func restorePurchases() {
        Task {
            let success = await premiumManager.restorePurchases()
            if !success {
                // Show alert that no purchases found
            }
        }
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
