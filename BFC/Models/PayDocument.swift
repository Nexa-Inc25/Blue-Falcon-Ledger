import Foundation
import SwiftData

/// An uploaded document: pay stub, NEAP statement, or foreman time sheet. We keep the
/// original bytes plus extracted text so the analysis engine can read it.
@Model
final class PayDocument {
    var kindRaw: String
    var fileName: String
    /// Extracted text (PDFKit / Vision OCR). Empty if extraction found nothing.
    var extractedText: String
    /// Original file bytes (PDF or image), stored externally.
    @Attribute(.externalStorage) var fileData: Data?
    var importedAt: Date

    var employer: Employer?
    var payPeriod: PayPeriod?

    var kind: PayDocumentKind {
        get { PayDocumentKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    init(
        kind: PayDocumentKind,
        fileName: String,
        extractedText: String = "",
        fileData: Data? = nil,
        importedAt: Date = .now
    ) {
        self.kindRaw = kind.rawValue
        self.fileName = fileName
        self.extractedText = extractedText
        self.fileData = fileData
        self.importedAt = importedAt
    }
}
