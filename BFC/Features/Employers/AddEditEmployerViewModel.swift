import Foundation
import SwiftData

/// Backs the Add/Edit Employer form. Handles labor-agreement PDF import + text
/// extraction, and the "only one current employer" rule.
@MainActor
@Observable
final class AddEditEmployerViewModel {
    var name = ""
    var ibewLocal = ""
    var perDiemText = ""        // entered as plain dollars, parsed to Decimal
    var homeAddress = ""
    var dependentsText = "0"
    var filingStatus: FilingStatus = .single
    var classification: LinemanClassification = .journeymanLineman
    var isCurrent = true

    // Agreement import state
    var agreementFileName: String?
    var agreementText: String = ""
    private var agreementData: Data?
    var isExtracting = false
    var extractionNote: String?

    var errorMessage: String?

    private let editing: Employer?

    var isEditing: Bool { editing != nil }
    var navigationTitle: String { isEditing ? "Edit Employer" : "Add Employer" }

    init(employer: Employer?) {
        self.editing = employer
        guard let e = employer else { return }
        name = e.name
        ibewLocal = e.ibewLocal
        perDiemText = NSDecimalNumber(decimal: e.perDiemRate).stringValue
        homeAddress = e.homeAddress
        dependentsText = String(e.dependents)
        filingStatus = e.filingStatus
        classification = e.classification
        isCurrent = e.isCurrent
        if let agreement = e.laborAgreement {
            agreementFileName = agreement.fileName
            agreementText = agreement.fullText
        }
    }

    var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Extract text from a picked PDF/image agreement.
    func importAgreement(_ file: ImportedFile) async {
        agreementData = file.data
        agreementFileName = file.fileName
        isExtracting = true
        extractionNote = nil
        let text = await PDFTextExtractor.extractText(from: file.data, fileName: file.fileName)
        agreementText = text
        isExtracting = false
        if text.isEmpty {
            extractionNote = "Couldn't pull any text out of that file. You can still keep it attached."
        } else {
            let words = text.split(whereSeparator: { $0.isWhitespace }).count
            extractionNote = "Extracted \(words) words."
        }
    }

    /// Create or update the employer in SwiftData.
    func save(context: ModelContext, allEmployers: [Employer]) -> Bool {
        guard canSave else {
            errorMessage = "Company name is required."
            return false
        }
        let perDiem = Decimal(string: perDiemText.replacingOccurrences(of: "$", with: "")) ?? 0
        let dependents = Int(dependentsText) ?? 0

        // Enforce single current employer.
        if isCurrent {
            for other in allEmployers where other.id != editing?.id {
                other.isCurrent = false
            }
        }

        let employer = editing ?? Employer(name: name)
        employer.name = name.trimmingCharacters(in: .whitespaces)
        employer.ibewLocal = ibewLocal.trimmingCharacters(in: .whitespaces)
        employer.perDiemRate = perDiem
        employer.homeAddress = homeAddress
        employer.dependents = dependents
        employer.filingStatus = filingStatus
        employer.classification = classification
        employer.isCurrent = isCurrent

        if editing == nil { context.insert(employer) }

        // Attach / update the agreement if one was imported or text exists.
        var agreementToChunk: LaborAgreement?
        if let fileName = agreementFileName, !agreementText.isEmpty || agreementData != nil {
            if let existing = employer.laborAgreement {
                let textChanged = existing.fullText != agreementText
                existing.fileName = fileName
                existing.fullText = agreementText
                if let data = agreementData { existing.pdfData = data }
                if textChanged { agreementToChunk = existing }
            } else {
                let agreement = LaborAgreement(fileName: fileName, fullText: agreementText, pdfData: agreementData)
                agreement.employer = employer
                employer.laborAgreement = agreement
                context.insert(agreement)
                agreementToChunk = agreement
            }
        }

        do {
            try context.save()
            // Split the agreement into retrievable chunks for RAG (only when changed).
            if let agreement = agreementToChunk, !agreement.fullText.isEmpty {
                AgreementChunker.rebuild(for: agreement, context: context)
            }
            return true
        } catch {
            errorMessage = "Couldn't save: \(error.localizedDescription)"
            return false
        }
    }
}
