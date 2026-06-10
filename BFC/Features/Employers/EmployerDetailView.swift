import SwiftUI
import SwiftData

/// Detail hub for one employer: info, agreement chat entry, set-current, edit.
struct EmployerDetailView: View {
    @Bindable var employer: Employer
    @Environment(\.modelContext) private var context
    @Query private var allEmployers: [Employer]
    @State private var showingEdit = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text(employer.name)
                        .font(Theme.title(28)).foregroundStyle(Theme.textPrimary)
                    if !employer.ibewLocal.isEmpty {
                        Text("IBEW Local \(employer.ibewLocal)")
                            .font(Theme.body()).foregroundStyle(Theme.textSecondary)
                    }
                }

                // Quick facts
                Card {
                    VStack(spacing: 12) {
                        DetailRow(label: "Per Diem", value: employer.perDiemRate.asMoney + " / day")
                        Divider().overlay(Theme.border)
                        DetailRow(label: "Days Logged", value: "\(employer.workDays.count)")
                        Divider().overlay(Theme.border)
                        DetailRow(label: "Filing Status", value: employer.filingStatus.rawValue)
                        if !employer.homeAddress.isEmpty {
                            Divider().overlay(Theme.border)
                            DetailRow(label: "Home Address", value: employer.homeAddress)
                        }
                    }
                }

                // Labor agreement + chat
                SectionHeader(title: "Labor Agreement")
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        if let agreement = employer.laborAgreement, !agreement.fullText.isEmpty {
                            Label(agreement.fileName, systemImage: "doc.fill")
                                .font(Theme.body(15)).foregroundStyle(Theme.textPrimary).lineLimit(1)
                            Text("\(agreement.wordCount) words ready to search")
                                .font(Theme.body(14)).foregroundStyle(Theme.textSecondary)
                            NavigationLink {
                                AgreementChatView(employer: employer)
                            } label: {
                                Label("Chat with the Agreement", systemImage: "bubble.left.and.text.bubble.right.fill")
                            }
                            .buttonStyle(.bfc)
                        } else {
                            Text("No agreement loaded. Add the PDF so the app can check your pay against it.")
                                .font(Theme.body(15)).foregroundStyle(Theme.textSecondary)
                            Button { showingEdit = true } label: {
                                Label("Upload Agreement", systemImage: "arrow.up.doc")
                            }
                            .buttonStyle(.bfcOutline)
                        }
                    }
                }

                // Set current
                if !employer.isCurrent {
                    Button {
                        for other in allEmployers { other.isCurrent = false }
                        employer.isCurrent = true
                        try? context.save()
                    } label: {
                        Label("Set as Current Employer", systemImage: "bolt.fill")
                    }
                    .buttonStyle(.bfcOutline)
                }
            }
            .padding(Theme.pad)
        }
        .bfcBackground()
        .navigationTitle(employer.isCurrent ? "Current" : "Employer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEdit = true }.foregroundStyle(Theme.accent)
            }
        }
        .sheet(isPresented: $showingEdit) { AddEditEmployerView(employer: employer) }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack(alignment: .top) {
            Text(label).font(Theme.body(15)).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(Theme.body(15)).foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }
}
