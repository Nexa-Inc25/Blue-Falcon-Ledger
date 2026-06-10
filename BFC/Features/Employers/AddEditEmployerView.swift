import SwiftUI
import SwiftData

/// Add or edit an employer, including labor-agreement PDF upload + text extraction.
struct AddEditEmployerView: View {
    let employer: Employer?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allEmployers: [Employer]
    @State private var vm: AddEditEmployerViewModel
    @State private var showingImporter = false

    init(employer: Employer?) {
        self.employer = employer
        _vm = State(initialValue: AddEditEmployerViewModel(employer: employer))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    BFCField(title: "Company Name", text: $vm.name, autocaps: .words)
                    BFCField(title: "IBEW Local Number", text: $vm.ibewLocal, keyboard: .numbersAndPunctuation)
                    BFCField(title: "Per Diem ($ per day worked)", text: $vm.perDiemText, keyboard: .decimalPad)
                    BFCField(title: "Home Address (for taxes)", text: $vm.homeAddress, autocaps: .words)
                    BFCField(title: "Dependents", text: $vm.dependentsText, keyboard: .numberPad)

                    // Classification
                    VStack(alignment: .leading, spacing: 6) {
                        SectionHeader(title: "Your Classification")
                        Picker("Classification", selection: $vm.classification) {
                            ForEach(LinemanClassification.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .tint(Theme.accent)
                        .frame(maxWidth: .infinity, minHeight: Theme.tapTarget, alignment: .leading)
                        .padding(.horizontal, 14)
                        .background(Theme.surfaceHigh)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
                        Text("Used so the analysis applies your wage rate (foreman, JL, operator…).")
                            .font(Theme.body(13)).foregroundStyle(Theme.textMuted)
                    }

                    // Filing status
                    VStack(alignment: .leading, spacing: 6) {
                        SectionHeader(title: "Tax Filing Status")
                        Picker("Filing Status", selection: $vm.filingStatus) {
                            ForEach(FilingStatus.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .tint(Theme.accent)
                        .frame(maxWidth: .infinity, minHeight: Theme.tapTarget, alignment: .leading)
                        .padding(.horizontal, 14)
                        .background(Theme.surfaceHigh)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
                    }

                    Toggle(isOn: $vm.isCurrent) {
                        Text("This is my current employer")
                            .font(Theme.body())
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .tint(Theme.accent)
                    .frame(minHeight: Theme.tapTarget)

                    // Labor agreement
                    agreementSection

                    if let error = vm.errorMessage {
                        Text(error).font(Theme.body(15)).foregroundStyle(Theme.danger)
                    }

                    Button {
                        if vm.save(context: context, allEmployers: allEmployers) { dismiss() }
                    } label: {
                        Text(vm.isEditing ? "Save Changes" : "Add Employer")
                    }
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
                        onError: { vm.extractionNote = $0 }) { file in
                Task { await vm.importAgreement(file) }
            }
        }
    }

    private var agreementSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Labor Agreement (PDF)")
                if let name = vm.agreementFileName {
                    Label(name, systemImage: "doc.fill")
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                }
                if vm.isExtracting {
                    HStack(spacing: 8) {
                        ProgressView().tint(Theme.accent)
                        Text("Reading the agreement…")
                            .font(Theme.body(15)).foregroundStyle(Theme.textSecondary)
                    }
                } else if let note = vm.extractionNote {
                    Text(note).font(Theme.body(14)).foregroundStyle(Theme.textSecondary)
                }
                Button {
                    showingImporter = true
                } label: {
                    Label(vm.agreementFileName == nil ? "Upload Agreement" : "Replace Agreement",
                          systemImage: "arrow.up.doc")
                }
                .buttonStyle(.bfcOutline)
                .disabled(vm.isExtracting)
            }
        }
    }
}
