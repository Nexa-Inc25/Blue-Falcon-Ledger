import SwiftUI
import SwiftData

/// Add or edit a credential: type, file/photo upload, dates, reminder.
struct AddEditCredentialView: View {
    let credential: Credential?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var vm: AddEditCredentialViewModel
    @State private var showingImporter = false
    @State private var showingCamera = false

    init(credential: Credential?) {
        self.credential = credential
        _vm = State(initialValue: AddEditCredentialViewModel(credential: credential))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Type
                    VStack(alignment: .leading, spacing: 6) {
                        SectionHeader(title: "Type")
                        Picker("Type", selection: $vm.kind) {
                            ForEach(CredentialKind.allCases) {
                                Label($0.rawValue, systemImage: $0.systemImage).tag($0)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Theme.accent)
                        .frame(maxWidth: .infinity, minHeight: Theme.tapTarget, alignment: .leading)
                        .padding(.horizontal, 14)
                        .background(Theme.surfaceHigh)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
                    }

                    BFCField(title: "Name (optional)", text: $vm.title, autocaps: .words)

                    // File upload
                    fileSection

                    // Dates
                    dateToggleRow(title: "Has an issue date", isOn: $vm.hasIssueDate)
                    if vm.hasIssueDate {
                        datePicker("Issued", selection: $vm.issueDate)
                    }

                    dateToggleRow(title: "Has an expiration / renewal date",
                                  isOn: Binding(get: { vm.hasExpiration },
                                                set: { vm.setExpirationToggled($0) }))
                    if vm.hasExpiration {
                        datePicker("Expires / renew by", selection: $vm.expirationDate)
                        Toggle(isOn: $vm.reminderEnabled) {
                            Text("Remind me before it expires")
                                .font(Theme.body()).foregroundStyle(Theme.textPrimary)
                        }
                        .tint(Theme.accent)
                        .frame(minHeight: Theme.tapTarget)
                    }

                    if let error = vm.errorMessage {
                        Text(error).font(Theme.body(15)).foregroundStyle(Theme.danger)
                    }

                    Button {
                        Task { if await vm.save(context: context) { dismiss() } }
                    } label: { Text(vm.isEditing ? "Save Changes" : "Add Credential") }
                        .buttonStyle(.bfc)
                        .disabled(!vm.canSave)
                }
                .padding(Theme.pad)
            }
            .bfcBackground()
            .navigationTitle(vm.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.textSecondary)
                }
            }
            .importFile(isPresented: $showingImporter,
                        onError: { vm.errorMessage = $0 }) { vm.importFile($0) }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker { vm.importFile($0) }.ignoresSafeArea()
            }
        }
    }

    private var fileSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Document")
                if let name = vm.fileName {
                    Label(name, systemImage: "doc.fill")
                        .font(Theme.body(15)).foregroundStyle(Theme.textPrimary).lineLimit(1)
                } else {
                    Text("Upload a PDF or photo of the card/document.")
                        .font(Theme.body(14)).foregroundStyle(Theme.textSecondary)
                }
                Menu {
                    Button { showingImporter = true } label: {
                        Label("Choose File", systemImage: "folder")
                    }
                    if cameraIsAvailable {
                        Button { showingCamera = true } label: {
                            Label("Take Photo", systemImage: "camera.fill")
                        }
                    }
                } label: {
                    Label(vm.fileName == nil ? "Add Document" : "Replace Document",
                          systemImage: "arrow.up.doc")
                }
                .buttonStyle(.bfcOutline)
            }
        }
    }

    private func dateToggleRow(title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title).font(Theme.body()).foregroundStyle(Theme.textPrimary)
        }
        .tint(Theme.accent)
        .frame(minHeight: Theme.tapTarget)
    }

    private func datePicker(_ label: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: label)
            DatePicker("", selection: selection, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(Theme.accent)
                .frame(maxWidth: .infinity, minHeight: Theme.tapTarget, alignment: .leading)
                .padding(.horizontal, 14)
                .background(Theme.surfaceHigh)
                .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
        }
    }
}
