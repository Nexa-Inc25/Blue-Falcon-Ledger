import SwiftUI

// MARK: - Buttons

/// Big, bold, glove-friendly primary button.
struct BFCButtonStyle: ButtonStyle {
    var fill: Color = Theme.accent
    var textColor: Color = .black

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.body(18))
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity, minHeight: Theme.tapTarget)
            .background(fill.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
    }
}

/// Outlined secondary button for less-prominent actions.
struct BFCOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.body())
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: Theme.tapTarget)
            .background(Theme.surfaceHigh.opacity(configuration.isPressed ? 0.6 : 1))
            .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
}

extension ButtonStyle where Self == BFCButtonStyle {
    static var bfc: BFCButtonStyle { BFCButtonStyle() }
    static func bfc(fill: Color, textColor: Color = .black) -> BFCButtonStyle {
        BFCButtonStyle(fill: fill, textColor: textColor)
    }
}

extension ButtonStyle where Self == BFCOutlineButtonStyle {
    static var bfcOutline: BFCOutlineButtonStyle { BFCOutlineButtonStyle() }
}

// MARK: - Card

/// Standard dark surface card.
struct Card<Content: View>: View {
    var padding: CGFloat = Theme.pad
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 13, weight: .heavy))
            .tracking(1.5)
            .foregroundStyle(Theme.textMuted)
    }
}

// MARK: - Labeled text field (dark)

struct BFCField: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var isSecure: Bool = false
    var autocaps: TextInputAutocapitalization = .sentences

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: title)
            Group {
                if isSecure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                }
            }
            .font(Theme.body())
            .foregroundStyle(Theme.textPrimary)
            .keyboardType(keyboard)
            .textInputAutocapitalization(autocaps)
            .autocorrectionDisabled(isSecure)
            .padding(.horizontal, 14)
            .frame(minHeight: Theme.tapTarget)
            .background(Theme.surfaceHigh)
            .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
    }
}

// MARK: - Empty state

struct EmptyHint: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
            Text(title)
                .font(Theme.headline())
                .foregroundStyle(Theme.textPrimary)
            Text(message)
                .font(Theme.body())
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Screen background

extension View {
    /// Apply the standard dark background edge-to-edge.
    func bfcBackground() -> some View {
        self.background(Theme.background.ignoresSafeArea())
    }
}
