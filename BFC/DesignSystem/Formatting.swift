import Foundation

extension Decimal {
    /// Currency string in the user's locale, e.g. "$185.00".
    var asMoney: String {
        let number = NSDecimalNumber(decimal: self)
        return Self.currencyFormatter.string(from: number) ?? "$0"
    }

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 2
        return f
    }()
}

extension Double {
    /// Hours formatted without trailing ".0", e.g. "8" or "8.5".
    var asHours: String {
        self == rounded() ? String(Int(self)) : String(format: "%.1f", self)
    }
}

extension String {
    /// Render light inline markdown (bold/italic) while preserving line breaks, falling
    /// back to plain text. The model is told to write plain text; this just keeps the UI
    /// clean if it still slips in a little markdown — no raw ** or * shown to the user.
    var asDisplayText: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        return (try? AttributedString(markdown: self, options: options)) ?? AttributedString(self)
    }
}

extension Date {
    var shortLabel: String {
        formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
    var rangeLabel: String {
        formatted(.dateTime.month(.abbreviated).day().year())
    }
}
