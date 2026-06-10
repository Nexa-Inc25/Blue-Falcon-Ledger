import SwiftUI
import SwiftData

/// Shows a pay period's numbers and the LLM's audit verdict. "Analyze" runs it.
struct AnalysisView: View {
    @Bindable var payPeriod: PayPeriod
    let employer: Employer
    @Environment(\.modelContext) private var context
    @State private var vm: AnalysisViewModel

    init(payPeriod: PayPeriod, employer: Employer) {
        self.payPeriod = payPeriod
        self.employer = employer
        _vm = State(initialValue: AnalysisViewModel(payPeriod: payPeriod, employer: employer))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Period summary
                Card {
                    VStack(spacing: 10) {
                        DetailRow(label: "Period",
                                  value: "\(payPeriod.startDate.rangeLabel) – \(payPeriod.endDate.rangeLabel)")
                        Divider().overlay(Theme.border)
                        Divider().overlay(Theme.border)
                        DetailRow(label: "Classification", value: employer.classification.rawValue)
                        Divider().overlay(Theme.border)
                        DetailRow(label: "Straight / OT / DT",
                                  value: "\(payPeriod.straightHours.asHours) / \(payPeriod.overtimeHours.asHours) / \(payPeriod.doubleHours.asHours) h")
                        Divider().overlay(Theme.border)
                        DetailRow(label: "Per Diem Days", value: "\(payPeriod.perDiemDays)")
                        if let paid = payPeriod.totalPayReceived {
                            Divider().overlay(Theme.border)
                            DetailRow(label: "Pay Received", value: paid.asMoney)
                        }
                    }
                }

                // Verdict
                if let result = payPeriod.analysisResult {
                    VerdictCard(result: result)
                }

                // Add context / correct, then re-run.
                VStack(alignment: .leading, spacing: 6) {
                    SectionHeader(title: payPeriod.analysisResult == nil ? "Add Details (optional)" : "Correct It & Re-run")
                    TextField("Tell it anything it got wrong or extra info — e.g. \"I'm a foreman\" or \"Sunday was a holiday\"…",
                              text: $payPeriod.correctionNote, axis: .vertical)
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2...5)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.surfaceHigh)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
                }

                if let error = vm.errorMessage {
                    Text(error).font(Theme.body(15)).foregroundStyle(Theme.danger)
                }

                Button {
                    Task { await vm.analyze(context: context) }
                } label: {
                    if vm.isRunning {
                        HStack(spacing: 8) {
                            ProgressView().tint(.black)
                            Text("Checking your pay…")
                        }
                    } else {
                        Label(payPeriod.analysisResult == nil ? "Analyze This Pay Period" : "Re-run Analysis",
                              systemImage: "magnifyingglass")
                    }
                }
                .buttonStyle(.bfc)
                .disabled(vm.isRunning)

                if !vm.hasAgreement {
                    Text("No labor agreement on file for \(employer.name). Add it on the employer screen.")
                        .font(Theme.body(14)).foregroundStyle(Theme.warn)
                }
            }
            .padding(Theme.pad)
        }
        .bfcBackground()
        .navigationTitle("Pay Analysis")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $vm.showPaywall) { PaywallView() }
    }
}

private struct VerdictCard: View {
    let result: AnalysisResult

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: result.verdict.systemImage)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(result.verdict.color)
                    Text(result.verdict.rawValue)
                        .font(Theme.headline(20))
                        .foregroundStyle(result.verdict.color)
                }
                Text(result.headline)
                    .font(Theme.headline(18))
                    .foregroundStyle(Theme.textPrimary)

                if let owed = result.amountOwed, owed > 0 {
                    Text("Estimated owed: \(owed.asMoney)")
                        .font(Theme.body(16))
                        .foregroundStyle(Theme.danger)
                }

                Divider().overlay(Theme.border)

                Text(result.detail.asDisplayText)
                    .font(Theme.body(16))
                    .foregroundStyle(Theme.textSecondary)
                    .textSelection(.enabled)

                Label("Not legal advice — verify with your hall before acting.",
                      systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Theme.corner)
                .stroke(result.verdict.color.opacity(0.6), lineWidth: 2)
        )
    }
}
