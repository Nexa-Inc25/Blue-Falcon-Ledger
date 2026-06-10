import Foundation
import StoreKit

/// Owns BFC Pro — Apple In-App Purchase (StoreKit 2) auto-renewable subscriptions with a
/// free trial. Apple handles payment, the trial, renewals, and cancellations; we just ask
/// "is this account subscribed?" and gate the metered feature (BFC Cloud) accordingly.
///
/// To go live: create these product IDs in App Store Connect as an auto-renewable
/// subscription group with a free-trial introductory offer (and add Products.storekit in
/// Xcode for simulator testing). Until then, products load empty and the free tier works.
@MainActor
@Observable
final class SubscriptionService {
    static let shared = SubscriptionService()

    static let monthlyID = "io.nexaus.bfc.pro.monthly"
    static let yearlyID = "io.nexaus.bfc.pro.yearly"
    static var productIDs: [String] { [monthlyID, yearlyID] }

    private(set) var products: [Product] = []
    private(set) var isPro = false
    private(set) var isLoading = false
    var lastError: String?

    private var updatesTask: Task<Void, Never>?

    private init() {
        // Listen for transactions that arrive outside a purchase (renewals, restores,
        // Ask-to-Buy approvals, purchases made on another device).
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
    }

    /// Load products + current entitlement. Call once at launch.
    func start() async {
        await loadProducts()
        await refreshEntitlement()
    }

    /// Load subscription products from the App Store. Retries a few times because
    /// StoreKit can return empty on a cold start (common during App Review on iPad).
    func loadProducts(maxAttempts: Int = 4) async {
        isLoading = true
        defer { isLoading = false }
        lastError = nil

        for attempt in 1...maxAttempts {
            do {
                let loaded = try await Product.products(for: Self.productIDs)
                if !loaded.isEmpty {
                    products = loaded.sorted { $0.price < $1.price }
                    return
                }
            } catch {
                lastError = error.localizedDescription
            }

            guard attempt < maxAttempts else { break }
            let delay = UInt64(attempt) * 1_500_000_000
            try? await Task.sleep(nanoseconds: delay)
        }

        if products.isEmpty, lastError == nil {
            lastError = "Subscription plans could not be loaded. Check your connection and try again."
        }
    }

    /// Recompute whether the account currently owns BFC Pro.
    func refreshEntitlement() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let txn) = result,
               Self.productIDs.contains(txn.productID),
               txn.revocationDate == nil {
                active = true
            }
        }
        isPro = active
    }

    /// Buy a subscription. Returns true if the user is Pro afterward.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        lastError = nil
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let txn) = verification {
                    await txn.finish()
                    await refreshEntitlement()
                }
                return isPro
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Restore purchases (required by App Review). Syncs with the App Store then re-checks.
    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlement()
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        if case .verified(let txn) = result {
            await txn.finish()
            await refreshEntitlement()
        }
    }

    // MARK: - Gating (only BFC Cloud is metered — it's the one that costs us tokens)

    /// BFC Cloud is the only provider that spends our money. On-device and bring-your-own-key
    /// providers are never gated.
    func isMetered(_ provider: LLMProvider) -> Bool { provider == .bfcCloud }

    /// Whether a request through `provider` is allowed right now.
    func cloudAllowed(provider: LLMProvider, settings: AppSettings = .shared) -> Bool {
        guard isMetered(provider) else { return true }
        if isPro { return true }
        // Never block when there's nothing to buy yet (subscriptions not live / not loaded).
        // You can't ask someone to upgrade to a plan that doesn't exist.
        if products.isEmpty { return true }
        return settings.freeCloudUsesRemaining > 0
    }

    /// Record a metered use for a free (non-Pro) user. Only counts once there's actually a
    /// purchasable plan, so beta usage doesn't pre-burn the free allowance.
    func noteUsage(provider: LLMProvider, settings: AppSettings = .shared) {
        guard isMetered(provider), !isPro, !products.isEmpty else { return }
        settings.consumeFreeCloudUse()
    }

    // MARK: - Display helpers

    var monthly: Product? { products.first { $0.id == Self.monthlyID } }
    var yearly: Product? { products.first { $0.id == Self.yearlyID } }

    func hasFreeTrial(_ product: Product) -> Bool {
        product.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }

    /// Human-readable renewal period, e.g. "1 month" or "1 year" (required disclosure).
    func subscriptionLength(_ product: Product) -> String? {
        guard let period = product.subscription?.subscriptionPeriod else { return nil }
        let n = period.value
        let unit: String
        switch period.unit {
        case .day: unit = "day"
        case .week: unit = "week"
        case .month: unit = "month"
        case .year: unit = "year"
        @unknown default: unit = "period"
        }
        let plural = n == 1 ? unit : "\(unit)s"
        return n == 1 ? "1 \(unit)" : "\(n) \(plural)"
    }

    /// e.g. "7-day free trial" if the product offers one.
    func trialDescription(_ product: Product) -> String? {
        guard let offer = product.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        let n = offer.period.value
        let unit: String
        switch offer.period.unit {
        case .day: unit = "day"; case .week: unit = "week"
        case .month: unit = "month"; case .year: unit = "year"
        @unknown default: unit = "day"
        }
        return "\(n)-\(unit)\(n > 1 ? "s" : "") free trial"
    }
}
