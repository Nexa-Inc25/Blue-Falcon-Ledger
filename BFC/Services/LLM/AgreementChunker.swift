import Foundation
import SwiftData

/// Splits a labor agreement's full text into logical, retrievable chunks. Prefers
/// article/section boundaries; falls back to overlapping fixed windows when a contract
/// has no detectable structure. Oversized sections are sub-split so no single chunk is
/// too big to retrieve cheaply.
struct AgreementChunker {
    /// Target ceiling for a single chunk (characters). Long sections get windowed.
    static let maxChunkChars = 1_800
    /// Overlap between windows so a rule split across a boundary still surfaces.
    static let windowOverlap = 200

    struct RawChunk {
        let heading: String
        let text: String
    }

    // MARK: - Public entry points

    /// (Re)build and persist chunks for an agreement. Safe to call repeatedly.
    @MainActor
    static func rebuild(for agreement: LaborAgreement, context: ModelContext) {
        for old in agreement.chunks { context.delete(old) }
        agreement.chunks.removeAll()

        let raw = chunk(agreement.fullText)
        for (index, piece) in raw.enumerated() {
            let chunk = AgreementChunk(order: index, heading: piece.heading, text: piece.text)
            // Precompute the semantic embedding so retrieval is fast at query time.
            chunk.embedding = SemanticIndex.vector(for: piece.heading + ". " + piece.text)
                .map(SemanticIndex.encode)
            chunk.agreement = agreement
            agreement.chunks.append(chunk)
            context.insert(chunk)
        }
        try? context.save()
    }

    /// Build chunks lazily for agreements imported before chunking existed.
    @MainActor
    static func ensureChunked(_ agreement: LaborAgreement, context: ModelContext) {
        guard agreement.chunks.isEmpty, !agreement.fullText.isEmpty else { return }
        rebuild(for: agreement, context: context)
    }

    // MARK: - Chunking logic

    /// Pure function: text in, chunks out. Exposed for testing/clarity.
    static func chunk(_ fullText: String) -> [RawChunk] {
        let text = fullText.replacingOccurrences(of: "\r\n", with: "\n")
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        let sections = splitByHeadings(text)
        let structured = sections.count >= 2 ? sections : windowed(heading: "Agreement", body: text)

        // Enforce the size ceiling on every section.
        var result: [RawChunk] = []
        for section in structured {
            if section.text.count <= maxChunkChars {
                result.append(section)
            } else {
                result.append(contentsOf: windowed(heading: section.heading, body: section.text))
            }
        }
        return result.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    // MARK: - Heading detection

    /// Matches a line that looks like an article/section heading. Immutable after
    /// build and `Regex` matching is read-only, so `nonisolated(unsafe)` is safe here.
    private static nonisolated(unsafe) let headingRegex: Regex<AnyRegexOutput>? = {
        // ARTICLE 5 / ARTICLE V / SECTION 5.3 / 5.3 Overtime / 5. OVERTIME / APPENDIX A
        let pattern = #"(?i)^\s*(article|section|appendix|addendum|schedule|exhibit)\b.*$|^\s*\d+(\.\d+)*\s*[.\-–)]?\s+\S.*$|^\s*[A-Z][A-Z0-9 ,'&/\-–]{6,}$"#
        return try? Regex(pattern)
    }()

    private static func isHeading(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3, trimmed.count <= 90 else { return false }
        guard let regex = headingRegex else { return false }
        return (try? regex.wholeMatch(in: trimmed)) != nil
    }

    private static func splitByHeadings(_ text: String) -> [RawChunk] {
        let lines = text.components(separatedBy: "\n")
        var chunks: [RawChunk] = []
        var currentHeading = ""
        var buffer: [String] = []

        func flush() {
            let body = buffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !body.isEmpty || !currentHeading.isEmpty {
                chunks.append(RawChunk(heading: currentHeading, text: body))
            }
            buffer.removeAll()
        }

        for line in lines {
            if isHeading(line) {
                flush()
                currentHeading = line.trimmingCharacters(in: .whitespaces)
            } else {
                buffer.append(line)
            }
        }
        flush()
        return chunks
    }

    // MARK: - Windowing (for long sections / unstructured text)

    private static func windowed(heading: String, body: String) -> [RawChunk] {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxChunkChars else {
            return [RawChunk(heading: heading, text: trimmed)]
        }

        // Prefer to cut on paragraph boundaries, packing up to the size ceiling.
        let paragraphs = trimmed.components(separatedBy: "\n\n").filter { !$0.isEmpty }
        var windows: [String] = []
        var current = ""

        func pushCurrent() {
            let piece = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !piece.isEmpty { windows.append(piece) }
        }

        for para in paragraphs {
            if para.count > maxChunkChars {
                // A single huge paragraph: hard-slice with overlap.
                pushCurrent(); current = ""
                windows.append(contentsOf: hardSlice(para))
            } else if current.count + para.count + 2 > maxChunkChars {
                pushCurrent()
                current = para
            } else {
                current += (current.isEmpty ? "" : "\n\n") + para
            }
        }
        pushCurrent()

        // Number the windows so citations stay meaningful.
        return windows.enumerated().map { index, piece in
            let label = windows.count > 1 ? "\(heading) (part \(index + 1))" : heading
            return RawChunk(heading: label, text: piece)
        }
    }

    /// Slice a too-long run of text into overlapping fixed windows.
    private static func hardSlice(_ text: String) -> [String] {
        var pieces: [String] = []
        let chars = Array(text)
        var start = 0
        while start < chars.count {
            let end = min(start + maxChunkChars, chars.count)
            pieces.append(String(chars[start..<end]))
            if end == chars.count { break }
            start = end - windowOverlap
        }
        return pieces
    }
}
