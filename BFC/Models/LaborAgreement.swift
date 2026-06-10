import Foundation
import SwiftData

/// The labor agreement (CBA) for an employer. We store the original PDF bytes plus
/// the full extracted text, which is what the LLM reasons over for chat and analysis.
@Model
final class LaborAgreement {
    var fileName: String
    /// Full extracted text (PDFKit + Vision OCR fallback). The source of truth for the LLM.
    var fullText: String
    /// Original PDF bytes, stored externally by SwiftData to keep the DB small.
    @Attribute(.externalStorage) var pdfData: Data?
    var importedAt: Date

    var employer: Employer?

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.agreement)
    var chatMessages: [ChatMessage] = []

    /// Retrievable slices of `fullText`. Built on import; used for RAG so we never
    /// send the entire contract to the model.
    @Relationship(deleteRule: .cascade, inverse: \AgreementChunk.agreement)
    var chunks: [AgreementChunk] = []

    var isChunked: Bool { !chunks.isEmpty }

    /// Rough size signal for the UI ("12,400 words extracted").
    var wordCount: Int {
        fullText.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    init(
        fileName: String,
        fullText: String = "",
        pdfData: Data? = nil,
        importedAt: Date = .now
    ) {
        self.fileName = fileName
        self.fullText = fullText
        self.pdfData = pdfData
        self.importedAt = importedAt
    }
}
