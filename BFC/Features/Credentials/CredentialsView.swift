import SwiftUI
import SwiftData

/// Credentials tab — a wallet for the docs you need to sign the books, gated behind
/// Face ID / passcode and with expiry status at a glance.
struct CredentialsView: View {
    @Environment(\.modelContext) private var context
    @Query private var credentials: [Credential]
    @State private var vm = CredentialsViewModel()
    @State private var lock = BiometricLock()
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if lock.isUnlocked {
                    listContent
                } else {
                    lockedScreen
                }
            }
            .bfcBackground()
            .navigationTitle("Credentials")
            .navigationDestination(for: Credential.self) { CredentialDetailView(credential: $0) }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if lock.isUnlocked {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showingAdd = true } label: {
                            Image(systemName: "plus").foregroundStyle(Theme.accent)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAdd) { AddEditCredentialView(credential: nil) }
        }
        .task { if !lock.isUnlocked { await lock.unlock() } }
    }

    // MARK: - Locked

    private var lockedScreen: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 48, weight: .heavy))
                .foregroundStyle(Theme.accent)
            Text("Your Credentials")
                .font(Theme.headline(22)).foregroundStyle(Theme.textPrimary)
            Text(lock.errorMessage ?? "Locked for your privacy. Unlock to view your cards and documents.")
                .font(Theme.body(15)).foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button { Task { await lock.unlock() } } label: {
                Label("Unlock", systemImage: "faceid")
            }
            .buttonStyle(.bfc)
            .padding(.horizontal, 40)
            Spacer()
        }
        .padding(Theme.pad)
    }

    // MARK: - List

    @ViewBuilder
    private var listContent: some View {
        if credentials.isEmpty {
            ScrollView {
                VStack(spacing: 16) {
                    Card {
                        EmptyHint(
                            systemImage: "person.text.rectangle",
                            title: "No credentials yet",
                            message: "Add your CPR card, OSHA 10, DOT physical, letter of rec, and dues receipt so they're ready when you sign the books."
                        )
                    }
                    Button { showingAdd = true } label: {
                        Label("Add Credential", systemImage: "plus")
                    }
                    .buttonStyle(.bfc)
                }
                .padding(Theme.pad)
            }
        } else {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(vm.sorted(credentials)) { credential in
                        NavigationLink(value: credential) {
                            CredentialRow(credential: credential)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                vm.delete(credential, context: context)
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                    Button { showingAdd = true } label: {
                        Label("Add Credential", systemImage: "plus")
                    }
                    .buttonStyle(.bfc)
                    .padding(.top, 4)
                }
                .padding(Theme.pad)
            }
        }
    }
}

// MARK: - Row

private struct CredentialRow: View {
    let credential: Credential
    var body: some View {
        Card(padding: 14) {
            HStack(spacing: 12) {
                Image(systemName: credential.kind.systemImage)
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 4) {
                    Text(credential.displayName)
                        .font(Theme.headline(18)).foregroundStyle(Theme.textPrimary)
                    CredentialStatusBadge(status: credential.status())
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.textMuted)
            }
        }
    }
}

/// Colored status line used by rows and the detail screen.
struct CredentialStatusBadge: View {
    let status: Credential.Status

    var body: some View {
        Label(text, systemImage: icon)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(color)
    }

    private var text: String {
        switch status {
        case .noExpiry: return "No expiration"
        case .valid(let d): return "Good — \(d) days left"
        case .expiringSoon(let d): return d == 0 ? "Expires today" : "Expires in \(d) days"
        case .expired: return "EXPIRED"
        }
    }
    private var icon: String {
        switch status {
        case .noExpiry: return "infinity"
        case .valid: return "checkmark.seal.fill"
        case .expiringSoon: return "clock.badge.exclamationmark"
        case .expired: return "exclamationmark.circle.fill"
        }
    }
    private var color: Color {
        switch status {
        case .noExpiry: return Theme.textMuted
        case .valid: return Theme.good
        case .expiringSoon: return Theme.warn
        case .expired: return Theme.danger
        }
    }
}
