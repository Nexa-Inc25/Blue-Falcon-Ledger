import SwiftUI
import SwiftData

/// Top-level gate: show auth when signed out, the tab bar when signed in. Ensures a
/// local `UserProfile` exists for the signed-in account.
struct RootView: View {
    @Environment(SessionStore.self) private var session
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context

    var body: some View {
        Group {
            #if DEBUG
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-screenshotPaywall") {
                PaywallView() // launch shortcut for the subscription review screenshot
            } else if args.contains(where: { $0.hasPrefix("-demo") }) {
                DemoHost() // seeds sample data + shows a screen for App Store screenshots
            } else {
                routedContent
            }
            #else
            routedContent
            #endif
        }
        .bfcBackground()
    }

    @ViewBuilder
    private var routedContent: some View {
        Group {
            if !settings.hasAcceptedDisclaimer {
                DisclaimerView()
            } else if session.isSignedIn {
                MainTabView()
                    .task(id: session.account?.id) { ensureProfile() }
            } else {
                LoginView()
            }
        }
        .bfcBackground()
    }

    /// Create a `UserProfile` the first time an account signs in.
    private func ensureProfile() {
        guard let account = session.account else { return }
        let id = account.id
        let descriptor = FetchDescriptor<UserProfile>(predicate: #Predicate { $0.accountId == id })
        let existing = (try? context.fetch(descriptor)) ?? []
        if existing.isEmpty {
            context.insert(UserProfile(accountId: account.id, email: account.email))
            try? context.save()
        }
    }
}
