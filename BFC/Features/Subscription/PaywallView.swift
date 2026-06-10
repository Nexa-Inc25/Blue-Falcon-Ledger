import SwiftUI
import StoreKit

/// BFL Pro paywall. Lists auto-renewable plans with the subscription disclosures App Review
/// requires: title, length, price, privacy policy, and Terms of Use (EULA).
struct PaywallView: View {
    @Environment(SubscriptionService.self) private var subs
    @Environment(\.dismiss) private var dismiss
    @State private var working = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    benefits
                    plans
                    if let error = subs.lastError, subs.products.isEmpty, !subs.isLoading {
                        Text(error).font(Theme.body(14)).foregroundStyle(Theme.danger)
                            .multilineTextAlignment(.center)
                    }
                    SubscriptionLegalFooter()
                }
                .padding(Theme.pad)
            }
            .bfcBackground()
            .navigationTitle("BFL Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }.foregroundStyle(Theme.textSecondary)
                }
            }
            .task { await subs.loadProducts() }
            .onChange(of: subs.isPro) { _, isPro in if isPro { dismiss() } }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "bolt.shield.fill")
                .font(.system(size: 48, weight: .heavy))
                .foregroundStyle(Theme.accent)
            Text("Catch what you're owed")
                .font(Theme.title(24)).foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text("Unlimited contract analysis and chat, powered by BFL Cloud.")
                .font(Theme.body(15)).foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var benefits: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                benefit("Unlimited pay-period audits", "magnifyingglass")
                benefit("Unlimited agreement chat", "bubble.left.and.text.bubble.right.fill")
                benefit("Reads your whole contract", "doc.text.fill")
                benefit("Checks pay AND benefits (NEAP, Lineco)", "checkmark.seal.fill")
            }
        }
    }

    private func benefit(_ text: String, _ icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Theme.accent).frame(width: 26)
            Text(text).font(Theme.body(16)).foregroundStyle(Theme.textPrimary)
            Spacer()
        }
    }

    @ViewBuilder
    private var plans: some View {
        if subs.isLoading, subs.products.isEmpty {
            Card {
                HStack(spacing: 12) {
                    ProgressView().tint(Theme.accent)
                    Text("Loading subscription plans…")
                        .font(Theme.body(15)).foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else if subs.products.isEmpty {
            #if DEBUG
            VStack(spacing: 12) {
                samplePlan(title: "BFL Pro (Monthly)", length: "1 month", price: "$7.99",
                           trial: "Start with a 7-day free trial")
                samplePlan(title: "BFL Pro (Yearly)", length: "1 year", price: "$59.99",
                           trial: "Start with a 7-day free trial")
            }
            #else
            Card {
                VStack(spacing: 14) {
                    Text("Subscription plans didn't load.")
                        .font(Theme.body(16)).foregroundStyle(Theme.textPrimary)
                    Text("Check your internet connection, then try again. If this keeps happening, update the app after the developer confirms subscriptions are live in App Store Connect.")
                        .font(Theme.body(14)).foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Try Again") { Task { await subs.loadProducts() } }
                        .buttonStyle(.bfc)
                }
            }
            #endif
        } else {
            VStack(spacing: 12) {
                ForEach(subs.products, id: \.id) { product in
                    Button {
                        Task {
                            working = true
                            await subs.purchase(product)
                            working = false
                        }
                    } label: {
                        planLabel(product)
                    }
                    .buttonStyle(.bfc)
                    .disabled(working)
                }
            }
        }
    }

    private func planLabel(_ product: Product) -> some View {
        let title = product.displayName.isEmpty ? planName(product) : product.displayName
        let length = subs.subscriptionLength(product) ?? "auto-renewing"
        return VStack(spacing: 4) {
            Text(title)
                .font(Theme.body(18))
            Text("\(product.displayPrice) per \(length)")
                .font(.system(size: 15, weight: .semibold))
            if let trial = subs.trialDescription(product) {
                Text("Start with a \(trial)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.7))
            }
        }
    }

    private func planName(_ product: Product) -> String {
        product.id == SubscriptionService.yearlyID ? "BFL Pro (Yearly)" : "BFL Pro (Monthly)"
    }

    #if DEBUG
    private func samplePlan(title: String, length: String, price: String, trial: String) -> some View {
        Button { } label: {
            VStack(spacing: 4) {
                Text(title).font(Theme.body(18))
                Text("\(price) per \(length)").font(.system(size: 15, weight: .semibold))
                Text(trial).font(.system(size: 13, weight: .semibold)).foregroundStyle(.black.opacity(0.7))
            }
        }
        .buttonStyle(.bfc)
    }
    #endif
}

/// Subscription legal copy + links — shown on the paywall and in Settings (Guideline 3.1.2).
struct SubscriptionLegalFooter: View {
    @Environment(SubscriptionService.self) private var subs

    var body: some View {
        VStack(spacing: 12) {
            Button("Restore Purchases") { Task { await subs.restore() } }
                .font(Theme.body(15)).foregroundStyle(Theme.accent).frame(minHeight: 44)

            Text("BFL Pro is an auto-renewable subscription. Payment is charged to your Apple Account at confirmation of purchase. Subscriptions renew automatically unless canceled at least 24 hours before the end of the current period. Your account is charged for renewal within 24 hours prior to the end of the period. Manage or cancel anytime in Settings → Apple ID → Subscriptions.")
                .font(.system(size: 12)).foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("Terms of Use", destination: AppLegal.termsOfUseURL)
                Link("Privacy Policy", destination: AppLegal.privacyPolicyURL)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
        }
    }
}
