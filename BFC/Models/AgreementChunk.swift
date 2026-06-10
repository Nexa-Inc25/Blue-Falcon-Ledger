import Foundation
import SwiftData

/// A retrievable slice of a labor agreement — one article/section (or a windowed
/// piece of a long one). We send only the most relevant chunks to the LLM instead of
/// the whole contract, so large agreements don't blow the context window.
@Model
final class AgreementChunk {
    /// Position in the document, for stable ordering and citation.
    var order: Int
    /// Best-guess heading, e.g. "ARTICLE 5 — OVERTIME" or "Section 5.3". Used for
    /// citations and to boost retrieval relevance.
    var heading: String
    var text: String
    /// On-device sentence embedding (encoded [Float]) for semantic retrieval. Optional so
    /// agreements chunked before semantic search still work (backfilled on demand).
    @Attribute(.externalStorage) var embedding: Data?

    var agreement: LaborAgreement?

    init(order: Int, heading: String, text: String, embedding: Data? = nil) {
        self.order = order
        self.heading = heading
        self.text = text
        self.embedding = embedding
    }

    /// What we hand the model: the heading followed by the body.
    var citationBlock: String {
        heading.isEmpty ? text : "[\(heading)]\n\(text)"
    }
}
