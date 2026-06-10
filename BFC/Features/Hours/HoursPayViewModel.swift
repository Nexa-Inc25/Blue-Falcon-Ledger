import Foundation
import SwiftData

/// Logic for the Hours & Pay tab: uploading documents (with text extraction) and
/// rolling logged days into a pay period for analysis.
@MainActor
@Observable
final class HoursPayViewModel {
    /// The doc kind the user chose before picking a file.
    var pendingKind: PayDocumentKind = .payStub
    var isUploading = false
    var statusMessage: String?

    /// Extract text from an uploaded document and store it on the employer.
    func upload(_ file: ImportedFile, kind: PayDocumentKind,
                employer: Employer, context: ModelContext) async {
        isUploading = true
        statusMessage = nil
        let text = await PDFTextExtractor.extractText(from: file.data, fileName: file.fileName)
        let doc = PayDocument(kind: kind, fileName: file.fileName,
                              extractedText: text, fileData: file.data)
        doc.employer = employer
        employer.documents.append(doc)
        context.insert(doc)
        try? context.save()
        isUploading = false
        statusMessage = text.isEmpty
            ? "Saved \(file.fileName), but no text could be read from it."
            : "Saved \(file.fileName)."
    }

    /// Build a pay period from every logged day not already in one. Returns nil if none.
    func createPeriodFromUnassignedDays(employer: Employer, context: ModelContext) -> PayPeriod? {
        let unassigned = employer.workDays.filter { $0.payPeriod == nil }
        guard !unassigned.isEmpty else {
            statusMessage = "No new logged days to analyze. Log some hours first."
            return nil
        }
        let dates = unassigned.map(\.date)
        let period = PayPeriod(startDate: dates.min() ?? .now, endDate: dates.max() ?? .now)
        period.employer = employer
        context.insert(period)
        for day in unassigned {
            day.payPeriod = period
            period.workDays.append(day)
        }
        // Pull in any unassigned uploaded stubs too.
        for doc in employer.documents where doc.payPeriod == nil {
            doc.payPeriod = period
            period.payStubs.append(doc)
        }
        employer.payPeriods.append(period)
        try? context.save()
        return period
    }

    func deleteDocument(_ doc: PayDocument, context: ModelContext) {
        context.delete(doc)
        try? context.save()
    }
}
