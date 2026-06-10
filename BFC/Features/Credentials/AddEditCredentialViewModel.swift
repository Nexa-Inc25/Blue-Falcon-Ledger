import Foundation
import SwiftData

/// Backs the Add/Edit Credential form: type, file upload, dates, reminder.
@MainActor
@Observable
final class AddEditCredentialViewModel {
    var kind: CredentialKind = .firstAidCPR {
        didSet { if !userToggledExpiry { hasExpiration = kind.usuallyExpires } }
    }
    var title = ""
    var notes = ""
    var hasIssueDate = false
    var issueDate = Date.now
    var hasExpiration = true
    var expirationDate = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now
    var reminderEnabled = true

    var fileName: String?
    private var fileData: Data?
    var errorMessage: String?

    private var userToggledExpiry = false
    private let editing: Credential?

    var isEditing: Bool { editing != nil }
    var navigationTitle: String { isEditing ? "Edit Credential" : "Add Credential" }

    init(credential: Credential?) {
        self.editing = credential
        guard let c = credential else {
            hasExpiration = kind.usuallyExpires
            return
        }
        kind = c.kind
        title = c.title
        notes = c.notes
        reminderEnabled = c.reminderEnabled
        fileName = c.fileName.isEmpty ? nil : c.fileName
        if let issue = c.issueDate { hasIssueDate = true; issueDate = issue }
        if let exp = c.expirationDate { hasExpiration = true; expirationDate = exp }
        else { hasExpiration = false }
        userToggledExpiry = true // don't auto-flip when editing
    }

    func setExpirationToggled(_ on: Bool) {
        userToggledExpiry = true
        hasExpiration = on
    }

    func importFile(_ file: ImportedFile) {
        fileData = file.data
        fileName = file.fileName
    }

    var canSave: Bool {
        // A credential is useful with at least a file or a custom title.
        fileName != nil || !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Create/update the credential and (re)schedule its reminder. Returns success.
    func save(context: ModelContext) async -> Bool {
        guard canSave else {
            errorMessage = "Add a file or a name so you can find it later."
            return false
        }

        let credential = editing ?? Credential(kind: kind)
        credential.kind = kind
        credential.title = title.trimmingCharacters(in: .whitespaces)
        credential.notes = notes
        credential.issueDate = hasIssueDate ? issueDate : nil
        credential.expirationDate = hasExpiration ? expirationDate : nil
        credential.reminderEnabled = reminderEnabled
        if let data = fileData {
            credential.fileData = data
            credential.fileName = fileName ?? "credential"
        }
        if editing == nil { context.insert(credential) }

        do {
            try context.save()
        } catch {
            errorMessage = "Couldn't save: \(error.localizedDescription)"
            return false
        }

        await NotificationService.shared.reschedule(for: credential)
        return true
    }
}
