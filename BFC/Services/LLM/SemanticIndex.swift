import Foundation
import NaturalLanguage
import SwiftData

/// On-device sentence embeddings for semantic retrieval. Uses Apple's NaturalLanguage
/// `NLEmbedding` — offline, no API key, no download. Powers the semantic half of the
/// hybrid retriever so questions match clauses by meaning, not just exact words.
struct SemanticIndex {
    /// Loaded once. Immutable; `NLEmbedding` reads are thread-safe, so `nonisolated(unsafe)`.
    private static nonisolated(unsafe) let model: NLEmbedding? =
        NLEmbedding.sentenceEmbedding(for: .english)

    /// Whether semantic scoring is available on this device/SDK.
    static var isAvailable: Bool { model != nil }

    /// Embed text into a vector. We embed the heading plus a representative slice of the
    /// body — enough to capture the topic without overloading the sentence model.
    static func vector(for text: String) -> [Float]? {
        guard let model else { return nil }
        let slice = String(text.prefix(500))
        guard let v = model.vector(for: slice) else { return nil }
        return v.map(Float.init)
    }

    // MARK: - Encoding for SwiftData (stored as Data on the chunk)

    static func encode(_ vector: [Float]) -> Data {
        vector.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    static func decode(_ data: Data) -> [Float] {
        let count = data.count / MemoryLayout<Float>.stride
        return data.withUnsafeBytes { raw in
            Array(raw.bindMemory(to: Float.self).prefix(count))
        }
    }

    // MARK: - Similarity

    /// Cosine similarity in [-1, 1]. Returns 0 for mismatched/empty vectors.
    static func cosine(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0, na: Float = 0, nb: Float = 0
        for i in a.indices {
            dot += a[i] * b[i]
            na += a[i] * a[i]
            nb += b[i] * b[i]
        }
        let denom = na.squareRoot() * nb.squareRoot()
        return denom > 0 ? dot / denom : 0
    }

    // MARK: - Backfill

    /// Compute embeddings for any chunks that don't have one yet (e.g. agreements
    /// chunked before semantic search existed). Safe to call repeatedly.
    @MainActor
    static func ensureEmbeddings(for agreement: LaborAgreement, context: ModelContext) {
        guard isAvailable else { return }
        var changed = false
        for chunk in agreement.chunks where chunk.embedding == nil {
            if let v = vector(for: chunk.heading + ". " + chunk.text) {
                chunk.embedding = encode(v)
                changed = true
            }
        }
        if changed { try? context.save() }
    }
}
