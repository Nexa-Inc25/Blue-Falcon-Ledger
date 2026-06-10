import SwiftUI
import SwiftData

/// One credential: status, details, view-the-document, edit, delete.
struct CredentialDetailView: View {
    @Bindable var credential: Credential
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var vm = CredentialsViewModel()
    @State private var showingEdit = false
    @State private var showingDocument = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: credential.kind.systemImage)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(credential.displayName)
                            .font(Theme.title(24)).foregroundStyle(Theme.textPrimary)
                        Text(credential.kind.rawValue)
                            .font(Theme.body(14)).foregroundStyle(Theme.textSecondary)
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        CredentialStatusBadge(status: credential.status())
                            .font(Theme.body(16))
                        if let issue = credential.issueDate {
                            Divider().overlay(Theme.border)
                            DetailRow(label: "Issued", value: issue.rangeLabel)
                        }
                        if let exp = credential.expirationDate {
                            Divider().overlay(Theme.border)
                            DetailRow(label: "Expires", value: exp.rangeLabel)
                            Divider().overlay(Theme.border)
                            DetailRow(label: "Reminder", value: credential.reminderEnabled ? "On" : "Off")
                        }
                        if !credential.notes.isEmpty {
                            Divider().overlay(Theme.border)
                            DetailRow(label: "Notes", value: credential.notes)
                        }
                    }
                }

                Button {
                    showingDocument = true
                } label: {
                    Label(credential.hasFile ? "View Document" : "No Document Attached",
                          systemImage: "eye.fill")
                }
                .buttonStyle(.bfc)
                .disabled(!credential.hasFile)

                Button(role: .destructive) {
                    vm.delete(credential, context: context)
                    dismiss()
                } label: { Label("Delete Credential", systemImage: "trash") }
                    .buttonStyle(.bfcOutline)
            }
            .padding(Theme.pad)
        }
        .bfcBackground()
        .navigationTitle("Credential")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEdit = true }.foregroundStyle(Theme.accent)
            }
        }
        .sheet(isPresented: $showingEdit) { AddEditCredentialView(credential: credential) }
        .fullScreenCover(isPresented: $showingDocument) {
            DocumentViewer(data: credential.fileData, fileName: credential.fileName)
        }
    }
}
