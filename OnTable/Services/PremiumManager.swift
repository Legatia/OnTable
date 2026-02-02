import Foundation
import SwiftUI
import StoreKit

// MARK: - Subscription Tier

enum SubscriptionTier: String, CaseIterable, Codable {
    case free = "free"
    case starter = "starter"
    case premium = "premium"

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .starter: return "Starter"
        case .premium: return "Premium"
        }
    }

    var monthlyPrice: String {
        switch self {
        case .free: return "Free"
        case .starter: return "$2.99/mo"
        case .premium: return "$7.99/mo"
        }
    }
}

// MARK: - Feature Flags

struct FeatureAccess {
    let tier: SubscriptionTier

    // Option limits
    var maxOptions: Int {
        switch tier {
        case .free: return 2
        case .starter, .premium: return 99
        }
    }

    var canAddMoreOptions: Bool {
        tier != .free
    }

    // Sharing features
    var canShare: Bool {
        tier != .free
    }

    var hasWatermark: Bool {
        tier == .free
    }

    var availableTemplates: [ShareCardTemplate] {
        switch tier {
        case .free:
            return [.classic]
        case .starter:
            return [.classic, .minimal, .bold, .sunset, .ocean, .forest, .neon, .paper]
        case .premium:
            return ShareCardTemplate.allCases
        }
    }

    func isTemplateUnlocked(_ template: ShareCardTemplate) -> Bool {
        switch tier {
        case .free:
            return !template.isPremiumOnly
        case .starter:
            return template != .custom
        case .premium:
            return true
        }
    }

    // Collaboration features
    var canHostRoom: Bool {
        tier != .free
    }

    var canJoinRoom: Bool {
        true // Everyone can join
    }

    // Premium-only features
    var hasPriorityWeights: Bool {
        tier == .premium
    }

    var hasDecisionTemplates: Bool {
        tier == .premium
    }

    var hasTemplates: Bool {
        hasDecisionTemplates
    }

    var hasOutcomeTracking: Bool {
        tier == .premium
    }

    var hasAICompanion: Bool {
        tier == .premium
    }
}

// MARK: - Premium Manager

@MainActor
class PremiumManager: ObservableObject {
    static let shared = PremiumManager()

    // Product identifiers
    static let starterProductId = "com.ontable.starter.monthly"
    static let premiumProductId = "com.ontable.premium.monthly"

    // Published state
    @Published private(set) var currentTier: SubscriptionTier = .free
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published var showPaywall = false

    // Persisted tier for offline access
    @AppStorage("currentTier") private var storedTier: String = SubscriptionTier.free.rawValue

    // Feature access helper
    var features: FeatureAccess {
        FeatureAccess(tier: currentTier)
    }

    // Unified paid status
    var isPremium: Bool {
        currentTier != .free
    }

    var isStarter: Bool {
        currentTier == .starter
    }

    func isTemplateUnlocked(_ template: ShareCardTemplate) -> Bool {
        features.isTemplateUnlocked(template)
    }

    private var updateListenerTask: Task<Void, Error>?

    init() {
        // Load stored tier
        if let tier = SubscriptionTier(rawValue: storedTier) {
            currentTier = tier
        }

        // Start listening for transactions
        updateListenerTask = listenForTransactions()

        // Load products and check entitlements
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - StoreKit 2 Integration

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let productIds = [Self.starterProductId, Self.premiumProductId]
            products = try await Product.products(for: productIds)
                .sorted { $0.price < $1.price }
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    func purchase(_ product: Product) async throws -> Bool {
        isLoading = true
        defer { isLoading = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateSubscriptionStatus()
            await transaction.finish()
            return true

        case .userCancelled:
            return false

        case .pending:
            return false

        @unknown default:
            return false
        }
    }

    func restorePurchases() async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
            return currentTier != .free
        } catch {
            print("Failed to restore purchases: \(error)")
            return false
        }
    }

    // MARK: - Transaction Handling

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { return }
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updateSubscriptionStatus()
                    await transaction.finish()
                } catch {
                    print("Transaction failed verification: \(error)")
                }
            }
        }
    }

    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    func updateSubscriptionStatus() async {
        var newTier: SubscriptionTier = .free
        var purchasedIds: Set<String> = []

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                if transaction.revocationDate == nil {
                    purchasedIds.insert(transaction.productID)

                    // Determine tier based on product
                    if transaction.productID == Self.premiumProductId {
                        newTier = .premium
                    } else if transaction.productID == Self.starterProductId && newTier != .premium {
                        newTier = .starter
                    }
                }
            } catch {
                print("Failed to verify transaction: \(error)")
            }
        }

        purchasedProductIDs = purchasedIds
        currentTier = newTier
        storedTier = newTier.rawValue
    }

    // MARK: - Helpers

    func product(for tier: SubscriptionTier) -> Product? {
        switch tier {
        case .free:
            return nil
        case .starter:
            return products.first { $0.id == Self.starterProductId }
        case .premium:
            return products.first { $0.id == Self.premiumProductId }
        }
    }

    // MARK: - Debug (remove in production)

    #if DEBUG
    func setTierForTesting(_ tier: SubscriptionTier) {
        currentTier = tier
        storedTier = tier.rawValue
    }
    #endif
}

// MARK: - Store Errors

enum StoreError: Error {
    case failedVerification
    case productNotFound
}

// MARK: - Feature Gate View

struct FeatureGate<Content: View, LockedContent: View>: View {
    @ObservedObject var premiumManager = PremiumManager.shared

    let requiredTier: SubscriptionTier
    let content: () -> Content
    let lockedContent: () -> LockedContent

    init(
        requiredTier: SubscriptionTier,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder lockedContent: @escaping () -> LockedContent
    ) {
        self.requiredTier = requiredTier
        self.content = content
        self.lockedContent = lockedContent
    }

    private var hasAccess: Bool {
        switch requiredTier {
        case .free:
            return true
        case .starter:
            return premiumManager.currentTier == .starter || premiumManager.currentTier == .premium
        case .premium:
            return premiumManager.currentTier == .premium
        }
    }

    var body: some View {
        if hasAccess {
            content()
        } else {
            lockedContent()
        }
    }
}

// MARK: - Legacy Support

struct PremiumFeature<Content: View, LockedContent: View>: View {
    @ObservedObject var premiumManager = PremiumManager.shared

    let content: () -> Content
    let lockedContent: () -> LockedContent

    init(
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder lockedContent: @escaping () -> LockedContent
    ) {
        self.content = content
        self.lockedContent = lockedContent
    }

    var body: some View {
        if premiumManager.isPremium {
            content()
        } else {
            lockedContent()
        }
    }
}
