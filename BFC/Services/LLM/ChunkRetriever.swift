import Foundation

/// Ranks agreement chunks against a query and returns only the most relevant ones,
/// under a character budget. Pure on-device lexical scoring (BM25) — no network, no
/// embeddings service — with a heading-match boost and lineman-term synonym expansion
/// so "OT"/"DT"/"sub" hit the right sections.
struct ChunkRetriever {

    struct Result {
        let chunks: [AgreementChunk]
        /// Concatenated, citation-friendly text to drop into the prompt.
        var contextText: String {
            chunks.map(\.citationBlock).joined(separator: "\n\n---\n\n")
        }
    }

    // BM25 parameters (standard defaults).
    private static let k1 = 1.5
    private static let b = 0.75
    /// Extra weight when a query term appears in the chunk heading.
    private static let headingBoost = 2.5

    /// Extra weight when a `boostTerm` shows up in a chunk heading / body. Fixed (not
    /// idf-scaled) so wage schedules and appendices surface on rate questions even when
    /// the user's literal words don't match.
    private static let boostHeadingWeight = 2.0
    private static let boostBodyWeight = 0.5

    /// Words that signal a pay/rate question — triggers broader retrieval.
    static let rateTriggerTerms: Set<String> = [
        "rate","rates","pay","paid","wage","wages","scale","overtime","double","foreman",
        "gf","premium","percent","percentage","differential","diem","subsistence","sub",
        "holiday","hourly","dollar","dollars","owed","money","classification","classifications",
        "journeyman","lineman","linemen","apprentice","operator","groundman","groundsman",
        "splicer","cable","equipment","general","check","time","zone","travel","mileage",
        "show","reporting","make","makes","earn","earns",
        "pension","annuity","neap","lineco","health","welfare","benefit","benefits","contribution",
        "vacation","dues","fringe","retirement","401k"
    ]

    /// Added to a rate query (so BM25 sees them) and used as `boostTerms` to pull in
    /// wage schedules / appendices / classification sections.
    static let rateBoostTerms: [String] = [
        "rate","premium","foreman","general","percentage","percent","wage","scale",
        "classification","differential","appendix","schedule","exhibit","journeyman",
        "lineman","apprentice","operator","groundman","splicer","equipment","hourly","zone","step",
        // Benefits — money paid on behalf of the employee.
        "pension","annuity","neap","lineco","health","welfare","benefit","contribution","vacation","dues","fringe"
    ]

    /// Specific job classifications a lineman might ask the rate for. Used to prioritize
    /// the chunk that actually names the asked-about classification.
    static let classificationTerms: Set<String> = [
        "foreman", "general", "operator", "operators", "groundman", "groundsman",
        "apprentice", "apprentices", "journeyman", "lineman", "linemen", "splicer",
        "cable", "equipment", "flagger", "helper"
    ]

    /// Whether a question is about pay/rates and warrants broader retrieval.
    static func isRateQuery(_ query: String) -> Bool {
        let terms = Set(expand(tokenize(query)))
        return !terms.isDisjoint(with: rateTriggerTerms)
    }

    /// Retrieve up to `limit` chunks whose combined text fits within `charBudget`.
    /// `boostTerms` get extra (fixed) weight wherever they appear, used to surface
    /// wage-schedule/appendix sections on rate questions.
    static func retrieve(query: String,
                         from chunks: [AgreementChunk],
                         limit: Int = 6,
                         charBudget: Int = 14_000,
                         boostTerms: [String] = []) -> Result {
        guard !chunks.isEmpty else { return Result(chunks: []) }

        let queryTerms = Array(Set(expand(tokenize(query))))
        let boostSet = Set(boostTerms)
        // No usable query terms (e.g. "what is it?") — fall back to leading chunks.
        guard !queryTerms.isEmpty else {
            return Result(chunks: takeWithinBudget(chunks.sorted { $0.order < $1.order },
                                                   limit: limit, charBudget: charBudget))
        }

        // Precompute tokens per chunk + document frequencies.
        let bodyTokens = chunks.map { tokenize($0.text) }
        let headingTokens = chunks.map { Set(tokenize($0.heading)) }
        let n = Double(chunks.count)
        let avgLen = max(1.0, Double(bodyTokens.reduce(0) { $0 + $1.count }) / n)

        var df: [String: Int] = [:]
        for tokens in bodyTokens {
            for term in Set(tokens) { df[term, default: 0] += 1 }
        }

        func idf(_ term: String) -> Double {
            let dft = Double(df[term] ?? 0)
            return log((n - dft + 0.5) / (dft + 0.5) + 1.0)
        }

        // --- Lexical (BM25 + boosts) score per chunk ---
        var lexical = [Double](repeating: 0, count: chunks.count)
        for i in chunks.indices {
            let tokens = bodyTokens[i]
            guard !tokens.isEmpty else { continue }
            var tf: [String: Int] = [:]
            for t in tokens { tf[t, default: 0] += 1 }
            let dl = Double(tokens.count)

            var score = 0.0
            for term in queryTerms {
                let f = Double(tf[term] ?? 0)
                if f > 0 {
                    let denom = f + k1 * (1 - b + b * dl / avgLen)
                    score += idf(term) * (f * (k1 + 1)) / denom
                }
                if headingTokens[i].contains(term) {
                    score += idf(term) * headingBoost
                }
            }
            // Rate-question boosts: surface wage schedules / appendices / classification
            // sections regardless of the user's exact wording.
            for term in boostSet {
                if headingTokens[i].contains(term) {
                    score += boostHeadingWeight
                } else if (tf[term] ?? 0) > 0 {
                    score += boostBodyWeight
                }
            }
            lexical[i] = score
        }
        let maxLexical = max(lexical.max() ?? 0, 1e-9)

        // --- Semantic (embedding cosine) score per chunk, if available ---
        let queryVector = SemanticIndex.vector(for: query)

        // --- Hybrid blend: normalized lexical + semantic. Lexical weighted a bit higher
        // so exact terms (rates, "double time") stay strong; semantic adds concept matches.
        let lexicalWeight = 0.6, semanticWeight = 0.4
        let scored: [(chunk: AgreementChunk, score: Double)] = chunks.indices.map { i in
            let lex = lexical[i] / maxLexical
            var combined = lex
            if let queryVector, let data = chunks[i].embedding {
                let sem = Double(max(0, SemanticIndex.cosine(queryVector, SemanticIndex.decode(data))))
                combined = lexicalWeight * lex + semanticWeight * sem
            }
            return (chunks[i], combined)
        }

        let ranked = scored.filter { $0.score > 0 }.sorted { $0.score > $1.score }
        // Nothing matched at all — return leading chunks so the model still has something.
        guard !ranked.isEmpty else {
            return Result(chunks: takeWithinBudget(chunks.sorted { $0.order < $1.order },
                                                   limit: limit, charBudget: charBudget))
        }

        let picked = takeWithinBudget(ranked.map(\.chunk), limit: limit, charBudget: charBudget)
        // Present in document order for readability/citation.
        return Result(chunks: picked.sorted { $0.order < $1.order })
    }

    /// Rate-question retrieval. On top of BM25, it guarantees the WHOLE wage-schedule /
    /// classification region reaches the model — every sibling window of a long table
    /// plus any rate-table chunks — so it reports all classifications (foreman, operator,
    /// groundman, apprentice steps…), not just journeyman lineman. Wage tables are
    /// prioritized so end-of-document appendices are never trimmed away.
    static func retrieveForRates(query: String,
                                 from chunks: [AgreementChunk],
                                 limit: Int = 12,
                                 charBudget: Int = 30_000) -> Result {
        guard !chunks.isEmpty else { return Result(chunks: []) }

        let augmented = query + " " + rateBoostTerms.joined(separator: " ")
        let ranked = retrieve(query: augmented, from: chunks, limit: limit,
                              charBudget: charBudget, boostTerms: rateBoostTerms).chunks

        // Group windows that came from the same section so we can pull whole tables in.
        let byBase = Dictionary(grouping: chunks, by: { baseHeading($0.heading) })
        func siblings(of chunk: AgreementChunk) -> [AgreementChunk] {
            byBase[baseHeading(chunk.heading)] ?? [chunk]
        }

        // Build a priority order:
        //  1. Chunks that name the SPECIFIC classification asked about (e.g. "foreman")
        //     — added before their sibling windows so the asked-for rate survives budget
        //     trimming even on the small on-device model.
        //  2. The rest of the wage-schedule / rate-table region (all sibling windows).
        //  3. The BM25 hits and their siblings.
        var ordered: [AgreementChunk] = []
        var seen = Set<Int>()
        func add(_ chunk: AgreementChunk) {
            guard !seen.contains(chunk.order) else { return }
            seen.insert(chunk.order)
            ordered.append(chunk)
        }
        func addWithSiblings(_ chunk: AgreementChunk) {
            add(chunk) // the matched chunk itself goes first
            for sib in siblings(of: chunk).sorted(by: { $0.order < $1.order }) { add(sib) }
        }

        let focus = Set(tokenize(query)).intersection(classificationTerms)
        if !focus.isEmpty {
            let focusChunks = chunks.filter { chunk in
                let hay = (chunk.heading + " " + chunk.text).lowercased()
                return focus.contains { hay.contains($0) }
            }.sorted { $0.order < $1.order }
            for chunk in focusChunks { addWithSiblings(chunk) }
        }

        let rateTables = chunks.filter(looksLikeRateTable).sorted { $0.order < $1.order }
        for table in rateTables { addWithSiblings(table) }
        for hit in ranked { addWithSiblings(hit) }

        // Take within budget in priority order, then present in document order.
        var picked: [AgreementChunk] = []
        var used = 0
        for chunk in ordered {
            let cost = chunk.citationBlock.count
            if used + cost > charBudget, !picked.isEmpty { continue }
            picked.append(chunk)
            used += cost
        }
        return Result(chunks: picked.sorted { $0.order < $1.order })
    }

    // MARK: - Helpers

    /// Strip a "(part N)" window suffix so sibling windows share a base heading.
    static func baseHeading(_ heading: String) -> String {
        guard let range = heading.range(of: " (part ") else { return heading }
        return String(heading[..<range.lowerBound])
    }

    /// Whether a chunk looks like a wage schedule / classification rate table.
    static func looksLikeRateTable(_ chunk: AgreementChunk) -> Bool {
        let heading = chunk.heading.lowercased()
        let headingSignals = ["wage", "schedule", "appendix", "classification", "rate sheet",
                              "exhibit", "pay scale", "foreman", "operator", "groundman",
                              "apprentice", "journeyman", "lineman"]
        if headingSignals.contains(where: heading.contains) { return true }

        // Body heuristic: a table usually names several classifications together.
        let body = chunk.text.lowercased()
        let classifications = ["foreman", "journeyman", "lineman", "operator", "groundman",
                               "apprentice", "cable splicer", "equipment operator"]
        return classifications.filter(body.contains).count >= 2
    }

    private static func takeWithinBudget(_ chunks: [AgreementChunk],
                                         limit: Int, charBudget: Int) -> [AgreementChunk] {
        var out: [AgreementChunk] = []
        var used = 0
        for chunk in chunks {
            if out.count >= limit { break }
            let cost = chunk.citationBlock.count
            if used + cost > charBudget, !out.isEmpty { break }
            out.append(chunk)
            used += cost
        }
        return out
    }

    private static let stopwords: Set<String> = [
        "the","a","an","and","or","of","to","in","on","for","is","are","be","was","were",
        "it","this","that","these","those","with","as","at","by","from","i","my","me",
        "do","does","did","what","when","how","much","many","get","got","you","your",
        "if","so","but","not","can","will","would","should","about","they","them","we"
    ]

    static func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 1 && !stopwords.contains($0) }
    }

    /// Expand lineman shorthand to the words contracts actually use.
    static func expand(_ tokens: [String]) -> [String] {
        var out = tokens
        for token in tokens {
            switch token {
            case "ot": out += ["overtime"]
            case "dt": out += ["double", "time"]
            case "doubletime": out += ["double", "time"]
            case "diem", "perdiem": out += ["per", "diem", "subsistence", "expense"]
            case "sub", "subsistence": out += ["per", "diem", "subsistence"]
            case "pd": out += ["per", "diem"]
            case "holiday", "holidays": out += ["holiday", "premium"]
            case "sat", "saturday": out += ["saturday", "overtime"]
            case "sun", "sunday": out += ["sunday", "double", "time"]
            case "scale", "wage", "wages", "pay": out += ["rate", "wage", "scale", "schedule", "classification"]
            case "rate", "rates": out += ["rate", "scale", "schedule", "classification", "wage"]
            case "shift": out += ["shift", "differential"]
            case "travel", "mileage": out += ["travel", "mileage", "zone"]
            case "show", "showup": out += ["show", "report", "reporting"]
            // Classifications — expand to the words wage schedules use so each one is findable.
            case "foreman", "gf": out += ["foreman", "general", "premium", "classification", "schedule"]
            case "general": out += ["general", "foreman", "classification"]
            case "operator", "operators": out += ["operator", "equipment", "classification", "schedule"]
            case "groundman", "groundsman", "grunt", "groundhand": out += ["groundman", "classification", "schedule"]
            case "apprentice", "apprentices": out += ["apprentice", "step", "classification", "schedule", "percent"]
            case "lineman", "linemen", "journeyman", "jl", "jw": out += ["journeyman", "lineman", "classification", "schedule"]
            case "splicer", "cable": out += ["cable", "splicer", "classification"]
            case "equipment": out += ["equipment", "operator", "classification"]
            case "classification", "classifications", "class": out += ["classification", "schedule", "rate", "wage"]
            // Non-pay topics so questions about working conditions also retrieve well.
            case "meal", "meals", "lunch", "dinner": out += ["meal", "lunch", "period", "penalty", "break"]
            case "break", "breaks", "rest": out += ["break", "rest", "meal", "period"]
            // Benefits — money paid on behalf of the lineman.
            case "neap", "pension", "annuity": out += ["pension", "annuity", "neap", "contribution", "retirement"]
            case "health", "welfare", "lineco": out += ["health", "welfare", "benefit", "contribution", "lineco"]
            case "benefit", "benefits", "fringe", "fringes": out += ["benefit", "pension", "health", "welfare", "annuity", "contribution"]
            case "401k", "retirement": out += ["retirement", "pension", "annuity", "contribution"]
            case "dues": out += ["dues", "checkoff", "deduction"]
            case "safety": out += ["safety", "protective", "ppe"]
            case "vacation", "vacations": out += ["vacation", "leave", "holiday"]
            case "grievance", "grievances", "dispute": out += ["grievance", "dispute", "arbitration"]
            case "drug", "testing": out += ["drug", "testing", "substance"]
            case "report", "reporting", "callout", "callback": out += ["report", "reporting", "call", "show"]
            default: break
            }
        }
        // Light singular/plural so "meals" matches "meal", "hours" matches "hour", etc.
        for token in tokens where token.count > 3 {
            if token.hasSuffix("s") {
                out.append(String(token.dropLast()))
            } else {
                out.append(token + "s")
            }
        }
        return out
    }
}
