import Foundation

/// Builds the LLM prompts for the two smart features and parses analysis verdicts.
/// This is where the app's real value lives — the prompt quality is the product.
@MainActor
struct AnalysisEngine {
    let llm: LLMService

    // MARK: - Labor agreement chat

    /// System prompt for the "expert on THIS agreement" chat. `excerpts` are the
    /// retrieved chunks most relevant to the user's question — NOT the whole contract.
    static func chatSystemPrompt(employer: Employer, excerpts: String) -> String {
        let body = excerpts.isEmpty
            ? "(No matching sections were found for this question.)"
            : excerpts
        let today = Date.now.formatted(.dateTime.month(.wide).day().year())
        return """
        You are a no-bullshit expert on this IBEW labor agreement. You help a journeyman \
        lineman understand his contract. Talk like a seasoned union hand: plain, direct, \
        blue-collar. Short answers. No corporate fluff.

        You can answer ANY question about this agreement — not just pay. That includes \
        overtime, per diem, wages, hours, meal periods and meal penalties, breaks, travel \
        and subsistence, holidays, safety, reporting/show-up pay, grievances, seniority, \
        and anything else the contract covers.

        Write the way you'd talk to the guy on the job: plain spoken English. Do NOT use \
        markdown formatting — no **asterisks** for bold, no # headings, no bullet symbols. \
        Just short, clear sentences and paragraphs.

        You are shown ONLY the excerpts below — the sections most relevant to the question, \
        not the whole contract.

        How to answer (be genuinely helpful, especially on pay/rate questions):
        - Lead with what the excerpts DO say. Quote rates, multipliers, and percentages \
          EXACTLY as written and cite the section in brackets, e.g. \
          "According to [ARTICLE 5 — OVERTIME], overtime is time and one-half the regular rate."
        - When money is involved, show the math using only numbers that appear in the excerpts.
        - If a multiplier/percentage is in the excerpts but the base rate isn't, explain the \
          rule and apply it symbolically (e.g. "double time = 2× your JL rate").
        - For rate/classification questions, list EVERY classification and rate shown in the \
          excerpts that's relevant — foreman, general foreman, equipment operator, groundman, \
          cable splicer, apprentice steps, etc. — not just the journeyman lineman rate. If the \
          wage schedule lists several classifications, report each one you can see.
        - PICK THE RIGHT YEAR. Wage schedules usually list several effective dates (the \
          contract runs 3–5 years with a raise each year). Today is \(today). Unless they ask \
          about a different year, give the rate IN EFFECT NOW and say which effective date it is.
        - THIS LINEMAN'S CLASSIFICATION is "\(employer.classification.rawValue)". When they ask \
          about "my rate," "my pay," "what do I make," etc., apply the wage row for THAT \
          classification (e.g. Foreman uses the Foreman rate) — not the journeyman rate by \
          default — unless they ask about a different classification.

        When the SPECIFIC number they asked about is NOT in the excerpts (common for \
        foreman/GF rates, which often live in a wage schedule or appendix):
        1. Give the related rules you CAN see (the JL rate if present, any foreman/premium \
           language, the relevant multiplier).
        2. You MAY add general industry context, but you MUST label it clearly as general — \
           e.g. "In many IBEW Outside Line agreements, foreman pay typically runs ~10–20% \
           above the journeyman lineman rate." Never present this as THIS contract's figure.
        3. Point them to the exact source: "Check your current referral / wage sheet, or the \
           hall, for the exact local number."

        Hard safety rule: NEVER state a specific dollar amount (or exact %) as THIS \
        contract's rate unless that exact number appears in the excerpts. Don't fall back \
        on "check with your hall" alone when you can explain the rule or give labeled context.

        EMPLOYER: \(employer.name)  |  IBEW LOCAL: \(employer.ibewLocal.isEmpty ? "—" : employer.ibewLocal)
        THIS LINEMAN'S CLASSIFICATION: \(employer.classification.rawValue)

        === RELEVANT AGREEMENT EXCERPTS ===
        \(body)
        === END EXCERPTS ===
        """
    }

    /// A query string that pulls the pay-relevant sections for an audit.
    static func analysisRetrievalQuery(payPeriod: PayPeriod) -> String {
        var terms = ["overtime", "double time", "straight time", "wage rate", "scale",
                     "per diem", "subsistence", "shift differential", "holiday",
                     "show up pay", "reporting pay", "travel", "zone", "foreman",
                     "classification", "premium", "percentage", "appendix", "schedule",
                     "meal", "meal period", "meal penalty", "lunch",
                     "pension", "annuity", "neap", "lineco", "health", "welfare", "benefit",
                     "contribution", "401k", "vacation", "dues", "fringe"]
        if payPeriod.doubleHours > 0 { terms += ["double time", "sunday", "holiday"] }
        if payPeriod.overtimeHours > 0 { terms += ["overtime", "time and one half", "saturday"] }
        if payPeriod.perDiemDays > 0 { terms += ["per diem", "subsistence", "expense"] }
        if payPeriod.mealsMissed > 0 { terms += ["meal", "meal period", "meal penalty", "lunch", "feed"] }
        return terms.joined(separator: " ")
    }

    // MARK: - Pay period analysis

    /// Run a strict pay-period audit and return a structured result. Retrieves only the
    /// pay-relevant excerpts so large contracts don't overflow the context window.
    func analyze(payPeriod: PayPeriod, employer: Employer) async throws -> AnalysisResult {
        let fullText = employer.laborAgreement?.fullText ?? ""
        let chunks = employer.laborAgreement?.chunks ?? []
        let budget = llm.analysisContextChars

        // For the audit we want the model to see EVERY rule — local agreements often have
        // non-standard ones (e.g. IBEW 1245 not paying an OT premium on property). On a
        // large-context cloud model, send the whole contract. On the small on-device model,
        // fall back to retrieving the most pay-relevant sections.
        let agreementContext: String
        if !fullText.isEmpty && fullText.count <= budget {
            agreementContext = fullText                                   // whole contract fits
        } else if budget >= 50_000 {
            agreementContext = LLMContext.clip(fullText, maxCharacters: budget) // most of it
        } else {
            let query = Self.analysisRetrievalQuery(payPeriod: payPeriod)
            agreementContext = ChunkRetriever.retrieveForRates(
                query: query, from: chunks, charBudget: max(2_000, budget * 2 / 3)).contextText
        }

        let system = Self.analysisSystemPrompt(employer: employer, excerpts: agreementContext)
        let user = Self.analysisUserPrompt(payPeriod: payPeriod, employer: employer,
                                           docCharBudget: max(800, budget / 3))
        let raw = try await llm.complete(system: system, messages: [.init(role: .user, content: user)])
        return Self.parse(raw)
    }

    private static func analysisSystemPrompt(employer: Employer, excerpts: String) -> String {
        let body = excerpts.isEmpty ? "(No agreement sections were available.)" : excerpts
        return """
        You are a relentless union payroll auditor for IBEW linemen. Your job: figure \
        out if this lineman got paid EXACTLY what the labor agreement requires, or if \
        they're getting brother fucked. Be extremely strict in your CHECKING, but concise \
        in what you write — catch everything, report it tight.

        Below is this employer's labor agreement — the full text when it fits, otherwise the \
        most relevant sections. Read it and base your audit ONLY on what it actually says.

        CRITICAL — do NOT assume standard industry rules. IBEW agreements vary a LOT. Some \
        locals do NOT pay an overtime or double-time premium for certain work (for example, \
        some utility work performed on company "property" is paid at straight time even past \
        8 hours). NEVER apply a time-and-a-half or double-time rate just because that's \
        common — apply ONLY the hours/overtime/double-time/premium rules written in THIS \
        agreement for THIS kind of work. If the lineman logged hours in the "OT" or "DT" \
        bucket but this agreement actually pays them at straight time, say so and correct it. \
        If a needed rule isn't in the agreement text, say it's not there — do not fill it in.

        FOCUS — what matters most is every dollar PAID TO or ON BEHALF OF this lineman: \
        their PAY and their BENEFITS. Audit both.

        PAY:
        - CLASSIFICATION: apply the wage figures for THIS lineman's classification (shown
          below) — e.g. a Foreman uses the Foreman rate, a Groundman uses the Groundman
          rate — NOT automatically the journeyman lineman rate. Pick the right row of the
          wage schedule for their classification.
        - Straight time rate and hours
        - Overtime: whether it even applies here, when it kicks in, and the multiplier
        - Double time: whether it applies, and when (Sundays, holidays, past X hours, etc.)
        - Shift differentials and any zone/travel pay
        - Per diem / subsistence: amount per day and the rules for qualifying
        - Meal periods / meal penalties: whether a penalty is owed for missed meals
        - Holiday pay, vacation pay, reporting/show-up pay, and any premiums

        BENEFITS (employer contributions made for the lineman — check these too):
        - Pension / annuity contributions (e.g. NEAP) — the rate and that hours were reported
        - Health & welfare contributions (e.g. Lineco)
        - 401(k) / supplemental retirement contributions
        - Any other fringe contributions, dues check-off, or money that affects their take

        HOW BENEFIT REPORTING WORKS (use this timing — don't flag contributions that aren't \
        due yet, but DO catch hours the employer never reported):
        - The employer reports hours and contributions to the funds (NEAP annuity, Lineco \
          health & welfare) MONTHLY, due by the 15th of the FOLLOWING month. So hours worked \
          in a month should be reported by the 15th of the next month.
        - NEAP STATEMENTS to the lineman come out QUARTERLY — so recently worked hours may \
          legitimately not appear on a statement yet if the quarter hasn't closed.
        - Compare the lineman's logged hours to any uploaded NEAP/benefit statement with this \
          timing in mind. If hours are still missing AFTER the reporting deadline has passed \
          (and a statement covering that period exists), flag it — the employer may have \
          failed to report hours to the fund. If it's simply not due yet, say so and don't \
          count it as a shortfall.

        TAXES & DEDUCTIONS (if a pay stub is provided, certify EACH deduction line — verify it's
        present and in the right ballpark; flag anything missing or off; don't give tax advice):
        - Federal income tax: withheld, and believable for the gross, filing status, and
          dependents below. Flag if zero or way off.
        - STATE income tax: withheld, and for the CORRECT state (their work state / home state
          below). Flag if it's missing, or withheld for the wrong state.
        - Local / city tax: if applicable to their work location, confirm it's present.
        - Social Security: about 6.2% of gross wages.
        - Medicare: about 1.45% of gross wages.
        - Union WORKING DUES / dues check-off: if the agreement states a dues rate (often a
          percentage of gross), confirm the deducted amount matches it. Flag if over- or
          under-deducted, or deducted when it shouldn't be.
        - Any other deduction on the stub: call out anything unexpected or that looks wrong.
        Do NOT compute exact tax owed or give tax advice. Flag what's missing or clearly off and
        say to confirm dues with the hall and taxes with a tax professional.

        Anything else in the contract (grievance procedure, seniority, general work rules) is \
        secondary — only mention it if it directly changes what they were paid or owed.

        If the lineman added a CORRECTION / ADDED CONTEXT note (in the data below), treat it as \
        authoritative new information and adjust your analysis accordingly.

        Rules:
        - PICK THE RIGHT YEAR. Wage schedules usually list several effective dates because \
          a contract runs 3–5 years with raises each year. Use the rate IN EFFECT for the \
          PAY PERIOD dates given below (today's date is also provided) — not an expired \
          earlier year and not a future one. State which effective date / column you used.
        - Quote rates, multipliers, and percentages EXACTLY as written in the agreement \
          and cite the section in brackets for each rule you apply.
        - If you have a multiplier but not the base rate (or vice-versa), still explain the \
          rule and apply it symbolically (e.g. "OT should be 1.5× your JL rate"). You may \
          add clearly-labeled general IBEW context, but never present it as this contract's number.
        - Do the math explicitly. AMOUNT_OWED must be computed ONLY from dollar figures that \
          actually appear in the agreement or the lineman's data — never from a guessed or \
          "typical" rate. If the specific rate needed for the dollar amount isn't in the \
          agreement, explain the likely issue but mark STATUS: NEED_INFO and AMOUNT_OWED: NONE.

        Respond in clear, direct, blue-collar language — plain spoken English, NO markdown \
        (no **asterisks**, no # headings, no bullet symbols).

        KEEP IT SHORT AND SCANNABLE — aim for UNDER 180 WORDS total. Lead with the bottom \
        line in one or two sentences, then only the specific findings that actually matter \
        (where the pay and the contract differ, or where you're missing info). Do NOT \
        restate the whole contract or walk through rules that checked out fine. A lineman \
        should be able to read the whole thing in about 20 seconds.

        Then end your reply with a machine-readable block EXACTLY in this format (no extra \
        text after it):

        ===VERDICT===
        STATUS: one of [LOOKS_GOOD | MINOR | SHORTED | NEED_INFO]
        HEADLINE: one short line, e.g. "Shorted 4 hrs double time — about $184 owed"
        AMOUNT_OWED: a number in dollars or NONE
        ===END===

        EMPLOYER: \(employer.name)  |  IBEW LOCAL: \(employer.ibewLocal.isEmpty ? "—" : employer.ibewLocal)
        LINEMAN'S CLASSIFICATION: \(employer.classification.rawValue)  ← apply this wage row
        PER DIEM RATE (from app): \(employer.perDiemRate)
        TAX CONTEXT: filing status \(employer.filingStatus.rawValue); \(employer.dependents) dependents; home address \(employer.homeAddress.isEmpty ? "not provided" : employer.homeAddress)

        === RELEVANT AGREEMENT EXCERPTS ===
        \(body)
        === END EXCERPTS ===
        """
    }

    private static func analysisUserPrompt(payPeriod: PayPeriod, employer: Employer,
                                           docCharBudget: Int) -> String {
        let df = DateFormatter()
        df.dateFormat = "EEE MMM d, yyyy"

        var lines: [String] = []
        lines.append("TODAY'S DATE: \(df.string(from: .now))")
        lines.append("PAY PERIOD: \(df.string(from: payPeriod.startDate)) → \(df.string(from: payPeriod.endDate))")
        lines.append("")
        lines.append("DAYS LOGGED BY THE LINEMAN:")
        if payPeriod.workDays.isEmpty {
            lines.append("  (none logged manually)")
        } else {
            for day in payPeriod.workDays.sorted(by: { $0.date < $1.date }) {
                let pd = day.perDiemReceived ? "per-diem: yes" : "per-diem: no"
                var line = "  \(df.string(from: day.date)): ST \(day.straightHours)h, OT \(day.overtimeHours)h, DT \(day.doubleHours)h, \(pd)"
                if day.mealsMissed > 0 { line += ", missed meals: \(day.mealsMissed)" }
                if !day.notes.isEmpty { line += " — note: \(day.notes)" }
                lines.append(line)
            }
        }
        lines.append("")
        lines.append("TOTALS: ST \(payPeriod.straightHours)h, OT \(payPeriod.overtimeHours)h, DT \(payPeriod.doubleHours)h, per-diem days \(payPeriod.perDiemDays), missed meals \(payPeriod.mealsMissed)")
        if let paid = payPeriod.totalPayReceived {
            lines.append("TOTAL PAY RECEIVED (per the lineman / stub): $\(paid)")
        } else {
            lines.append("TOTAL PAY RECEIVED: not entered")
        }

        if !payPeriod.payStubs.isEmpty {
            // Split the document budget across the uploaded stubs so the whole prompt
            // stays within the model's window.
            let perDoc = max(400, docCharBudget / payPeriod.payStubs.count)
            lines.append("")
            lines.append("UPLOADED DOCUMENTS (extracted text):")
            for doc in payPeriod.payStubs {
                lines.append("--- \(doc.kind.rawValue): \(doc.fileName) ---")
                lines.append(LLMContext.clip(doc.extractedText, maxCharacters: perDoc))
            }
        }

        if !payPeriod.correctionNote.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.append("")
            lines.append("CORRECTION / ADDED CONTEXT FROM THE LINEMAN (treat as authoritative): \(payPeriod.correctionNote)")
        }

        lines.append("")
        lines.append("Audit this pay period against the agreement. Did they get paid right?")
        return lines.joined(separator: "\n")
    }

    // MARK: - Parsing

    /// Pull the structured verdict block out of the model's reply; keep the prose as detail.
    static func parse(_ raw: String) -> AnalysisResult {
        let detail: String
        var status = "NEED_INFO"
        var headline = "Review the breakdown below"
        var amount: Decimal?

        if let range = raw.range(of: "===VERDICT===") {
            detail = String(raw[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let block = String(raw[range.upperBound...])
            for line in block.split(separator: "\n") {
                let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                guard parts.count == 2 else { continue }
                switch parts[0].uppercased() {
                case "STATUS": status = parts[1].uppercased()
                case "HEADLINE": headline = parts[1]
                case "AMOUNT_OWED":
                    let cleaned = parts[1].replacingOccurrences(of: "$", with: "")
                        .replacingOccurrences(of: ",", with: "")
                    if let value = Decimal(string: cleaned), parts[1].uppercased() != "NONE" {
                        amount = value
                    }
                default: break
                }
            }
        } else {
            detail = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let verdict: AnalysisVerdict
        switch status {
        case "LOOKS_GOOD": verdict = .looksGood
        case "MINOR": verdict = .minor
        case "SHORTED": verdict = .shorted
        default: verdict = .needsInfo
        }

        return AnalysisResult(
            verdict: verdict,
            headline: headline,
            detail: detail.isEmpty ? "No breakdown returned." : detail,
            amountOwed: amount
        )
    }
}
