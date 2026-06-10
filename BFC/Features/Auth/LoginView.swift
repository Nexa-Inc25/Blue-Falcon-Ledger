import SwiftUI

/// Login / sign-up. Email + password only — no social login (per spec).
struct LoginView: View {
    @Environment(SessionStore.self) private var session
    @State private var vm = AuthViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 60)

                // Brand
                VStack(spacing: 8) {
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 56, weight: .heavy))
                        .foregroundStyle(Theme.accent)
                    Text("BFL")
                        .font(Theme.title(44))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Blue Falcon Ledger")
                        .font(Theme.body())
                        .foregroundStyle(Theme.textSecondary)
                    Text("Know what you're owed.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textMuted)
                }

                VStack(spacing: 16) {
                    BFCField(title: "Email", text: $vm.email,
                             keyboard: .emailAddress, autocaps: .never)

                    BFCField(title: "Password", text: $vm.password, isSecure: true)

                    if vm.mode == .signUp {
                        BFCField(title: "Confirm Password",
                                 text: $vm.confirmPassword, isSecure: true)
                    }

                    if let error = vm.errorMessage {
                        Text(error)
                            .font(Theme.body(15))
                            .foregroundStyle(Theme.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { await vm.submit(using: session) }
                    } label: {
                        if vm.isWorking {
                            ProgressView().tint(.black)
                        } else {
                            Text(vm.actionTitle)
                        }
                    }
                    .buttonStyle(.bfc)
                    .disabled(vm.isWorking)

                    Button(vm.toggleTitle) { vm.toggleMode() }
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.accent)
                        .frame(minHeight: 44)
                }
                .padding(.horizontal, Theme.pad)

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .bfcBackground()
    }
}
