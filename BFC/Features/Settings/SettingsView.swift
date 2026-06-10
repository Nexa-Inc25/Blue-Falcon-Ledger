import SwiftUI

/// Settings: pick the LLM brain, store its API key, choose auth backend, sign out.
struct SettingsView: View {
    @Environment(SessionStore.self) private var session
    @Environment(AppSettings.self) private var settings
    @Environment(SubscriptionService.self) private var subs
    @State private var apiKeyInput = ""
    @State private var savedNote = false
    @State private var showingPaywall = false

    var body: some View {
        @Bindable var settings = settings
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {

                // Subscription
                SectionHeader(title: "BFL Pro")
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        if subs.isPro {
                            Label("Pro is active — unlimited BFL Cloud", systemImage: "checkmark.seal.fill")
                                .font(Theme.body(15)).foregroundStyle(Theme.good)
                            Text("Manage or cancel in Settings → your Apple ID → Subscriptions.")
                                .font(Theme.body(13)).foregroundStyle(Theme.textMuted)
                        } else {
                            Text("Free — \(settings.freeCloudUsesRemaining) BFL Cloud uses left. On-device and your own API key stay unlimited.")
                                .font(Theme.body(15)).foregroundStyle(Theme.textSecondary)
                            Button { showingPaywall = true } label: {
                                Label("Go Pro", systemImage: "bolt.fill")
                            }
                            .buttonStyle(.bfc)
                        }
                        Button("Restore Purchases") { Task { await subs.restore() } }
                            .font(Theme.body(14)).foregroundStyle(Theme.accent).frame(minHeight: 44)

                        HStack(spacing: 16) {
                            Link("Terms of Use", destination: AppLegal.termsOfUseURL)
                            Link("Privacy Policy", destination: AppLegal.privacyPolicyURL)
                        }
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.textSecondary)
                    }
                }

                // Account
                SectionHeader(title: "Account")
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        if let email = session.account?.email {
                            DetailRow(label: "Signed in as", value: email)
                        }
                        Button(role: .destructive) {
                            session.signOut()
                        } label: { Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right") }
                            .buttonStyle(.bfcOutline)
                    }
                }

                // LLM brain
                SectionHeader(title: "Analysis Brain")
                Card {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("Provider", selection: $settings.llmProvider) {
                            ForEach(LLMProvider.allCases) { provider in
                                Label(provider.rawValue, systemImage: provider.systemImage).tag(provider)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Theme.accent)

                        Text(providerBlurb)
                            .font(Theme.body(14)).foregroundStyle(Theme.textSecondary)

                        if settings.llmProvider == .bfcCloud {
                            Label(AppConfig.proxyConfigured ? "BFL Cloud is connected" : "BFL Cloud not set up — using on-device for now",
                                  systemImage: AppConfig.proxyConfigured ? "checkmark.icloud.fill" : "exclamationmark.icloud")
                                .font(Theme.body(14))
                                .foregroundStyle(AppConfig.proxyConfigured ? Theme.good : Theme.warn)
                        }

                        if settings.llmProvider.requiresAPIKey {
                            BFCField(title: "\(settings.llmProvider.rawValue) API Key",
                                     text: $apiKeyInput, isSecure: true, autocaps: .never)
                            Button {
                                settings.setAPIKey(apiKeyInput, for: settings.llmProvider)
                                apiKeyInput = ""
                                savedNote = true
                            } label: { Text("Save Key") }
                                .buttonStyle(.bfc)

                            Label(settings.hasAPIKey(for: settings.llmProvider)
                                  ? "Key saved in Keychain" : "No key saved yet",
                                  systemImage: settings.hasAPIKey(for: settings.llmProvider)
                                  ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                                .font(Theme.body(14))
                                .foregroundStyle(settings.hasAPIKey(for: settings.llmProvider) ? Theme.good : Theme.warn)
                        }
                    }
                }

                // Auth backend
                SectionHeader(title: "Sign-In Backend")
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Backend", selection: $settings.authBackend) {
                            ForEach(AuthBackend.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: settings.authBackend) { session.refreshBackend() }

                        Text("On-Device works offline out of the box. Firebase activates once you add the Firebase package (see project docs).")
                            .font(Theme.body(13)).foregroundStyle(Theme.textMuted)
                    }
                }

                Text("Blue Falcon Ledger keeps everything on your phone. Keys and credentials live in the iOS Keychain.")
                    .font(Theme.body(13)).foregroundStyle(Theme.textMuted)
                    .padding(.top, 4)
            }
            .padding(Theme.pad)
        }
        .bfcBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("Saved", isPresented: $savedNote) {
            Button("OK", role: .cancel) { }
        } message: { Text("Your API key is stored securely in the Keychain.") }
        .sheet(isPresented: $showingPaywall) { PaywallView() }
    }

    private var providerBlurb: String {
        switch settings.llmProvider {
        case .bfcCloud: return "Recommended. Uses BFL's Claude backend — no key needed. Best for reading whole contracts."
        case .appleOnDevice: return "Runs on your iPhone. Private and free. Needs Apple Intelligence (iOS 26)."
        case .claude: return "Anthropic Claude. Strong at reading long agreements. Needs an API key."
        case .openai: return "OpenAI GPT models. Needs an API key."
        case .grok: return "xAI Grok. Needs an API key."
        }
    }
}
