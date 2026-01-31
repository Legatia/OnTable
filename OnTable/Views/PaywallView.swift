import SwiftUI
import StoreKit

struct PaywallView: View {
    @ObservedObject var premiumManager = PremiumManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTier: SubscriptionTier = .starter
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showingPrivacy = false
    @State private var showingTerms = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Tier cards
                    tierCardsSection

                    // Feature comparison
                    featureComparisonSection

                    // Purchase button
                    purchaseButton

                    // Restore purchases
                    restoreButton

                    // Terms
                    termsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "scalemass.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Unlock Your Full Potential")
                .font(.title2)
                .fontWeight(.bold)

            Text("Make better decisions with powerful tools")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top)
    }

    // MARK: - Tier Cards

    private var tierCardsSection: some View {
        VStack(spacing: 12) {
            TierCard(
                tier: .starter,
                isSelected: selectedTier == .starter,
                isCurrent: premiumManager.currentTier == .starter,
                product: premiumManager.product(for: .starter)
            ) {
                selectedTier = .starter
            }

            TierCard(
                tier: .premium,
                isSelected: selectedTier == .premium,
                isCurrent: premiumManager.currentTier == .premium,
                product: premiumManager.product(for: .premium),
                badge: "Best Value"
            ) {
                selectedTier = .premium
            }
        }
    }

    // MARK: - Feature Comparison

    private var featureComparisonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Compare Plans")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 0) {
                FeatureRow(
                    feature: "Decision Options",
                    free: "2 max",
                    starter: "Unlimited",
                    premium: "Unlimited"
                )

                FeatureRow(
                    feature: "Share to Social",
                    free: false,
                    starter: true,
                    premium: true
                )

                FeatureRow(
                    feature: "Host Rooms",
                    free: false,
                    starter: true,
                    premium: true
                )

                FeatureRow(
                    feature: "Watermark-free",
                    free: false,
                    starter: false,
                    premium: true
                )

                FeatureRow(
                    feature: "All Templates",
                    free: false,
                    starter: false,
                    premium: true
                )

                FeatureRow(
                    feature: "Priority Weights",
                    free: false,
                    starter: false,
                    premium: true
                )

                FeatureRow(
                    feature: "Decision Templates",
                    free: false,
                    starter: false,
                    premium: true
                )

                FeatureRow(
                    feature: "Outcome Tracking",
                    free: false,
                    starter: false,
                    premium: true
                )

                FeatureRow(
                    feature: "AI Companion",
                    free: false,
                    starter: false,
                    premium: true,
                    isLast: true
                )
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Purchase Button

    private var purchaseButton: some View {
        Button(action: purchase) {
            HStack {
                if isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Subscribe to \(selectedTier.displayName)")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(selectedTier == .premium ? Color.purple : Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isPurchasing || premiumManager.currentTier == selectedTier)
    }

    private var restoreButton: some View {
        Button("Restore Purchases") {
            Task {
                isPurchasing = true
                let success = await premiumManager.restorePurchases()
                isPurchasing = false
                if success {
                    dismiss()
                }
            }
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
    }

    // MARK: - Terms

    private var termsSection: some View {
        VStack(spacing: 4) {
            Text("Subscriptions auto-renew monthly until cancelled.")
                .font(.caption2)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                Button("Terms of Use") {
                    showingTerms = true
                }
                Button("Privacy Policy") {
                    showingPrivacy = true
                }
            }
            .font(.caption2)
            .foregroundColor(.accentColor)
        }
        .padding(.bottom)
        .sheet(isPresented: $showingTerms) {
            LegalView(documentType: .termsOfService)
        }
        .sheet(isPresented: $showingPrivacy) {
            LegalView(documentType: .privacyPolicy)
        }
    }

    // MARK: - Actions

    private func purchase() {
        guard let product = premiumManager.product(for: selectedTier) else {
            errorMessage = "Product not available. Please try again later."
            return
        }

        Task {
            isPurchasing = true
            do {
                let success = try await premiumManager.purchase(product)
                if success {
                    dismiss()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isPurchasing = false
        }
    }
}

// MARK: - Tier Card

struct TierCard: View {
    let tier: SubscriptionTier
    let isSelected: Bool
    let isCurrent: Bool
    let product: Product?
    var badge: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(tier.displayName)
                                .font(.headline)
                                .foregroundColor(.primary)

                            if let badge = badge {
                                Text(badge)
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.purple)
                                    .cornerRadius(4)
                            }

                            if isCurrent {
                                Text("Current")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }

                        if let product = product {
                            Text(product.displayPrice + "/month")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text(tier.monthlyPrice)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                }

                // Quick features
                HStack(spacing: 16) {
                    if tier == .starter {
                        FeaturePill(icon: "infinity", text: "Unlimited Options")
                        FeaturePill(icon: "square.and.arrow.up", text: "Share")
                        FeaturePill(icon: "person.2", text: "Rooms")
                    } else if tier == .premium {
                        FeaturePill(icon: "sparkles", text: "AI")
                        FeaturePill(icon: "star.fill", text: "All Features")
                        FeaturePill(icon: "checkmark.seal", text: "No Watermark")
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Feature Pill

struct FeaturePill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .foregroundColor(.secondary)
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let feature: String
    var free: Any = false
    var starter: Any = false
    var premium: Any = false
    var isLast: Bool = false

    var body: some View {
        HStack {
            Text(feature)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)

            featureCell(free)
            featureCell(starter)
            featureCell(premium)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5),
            alignment: .bottom
        )
        .opacity(isLast ? 1 : 1)
    }

    @ViewBuilder
    private func featureCell(_ value: Any) -> some View {
        Group {
            if let bool = value as? Bool {
                Image(systemName: bool ? "checkmark" : "xmark")
                    .font(Font.caption.weight(.semibold))
                    .foregroundColor(bool ? .green : .secondary.opacity(0.5))
            } else if let string = value as? String {
                Text(string)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
        .frame(width: 60)
    }
}

// MARK: - Preview

struct PaywallView_Previews: PreviewProvider {
    static var previews: some View {
        PaywallView()
    }
}
