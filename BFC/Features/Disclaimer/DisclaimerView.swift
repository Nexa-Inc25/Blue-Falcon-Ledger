import SwiftUI

/// First-run disclaimer. Makes clear BFC is a helper, not legal advice. Shown until the
/// user acknowledges it, then never again (unless storage is reset).
struct DisclaimerView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 56, weight: .heavy))
                .foregroundStyle(Theme.accent)

            Text("Read This First")
                .font(Theme.title(30))
                .foregroundStyle(Theme.textPrimary)

            Text(AppSettings.disclaimerText)
                .font(Theme.body(17))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 4)

            Text("Your contracts and pay info stay on your phone.")
                .font(Theme.body(14))
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                settings.hasAcceptedDisclaimer = true
            } label: {
                Text("I Understand — Continue")
            }
            .buttonStyle(.bfc)
        }
        .padding(Theme.pad)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .bfcBackground()
    }
}
