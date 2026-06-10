import SwiftUI
import SwiftData

/// Log a day's hours. Big stepper-style fields and a very prominent voice button for
/// the notes (gloves on, hands-free).
struct LogHoursView: View {
    let employer: Employer
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var vm: LogHoursViewModel

    init(employer: Employer) {
        self.employer = employer
        _vm = State(initialValue: LogHoursViewModel(employer: employer))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Date
                    VStack(alignment: .leading, spacing: 6) {
                        SectionHeader(title: "Day Worked")
                        DatePicker("", selection: $vm.date, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(Theme.accent)
                            .frame(maxWidth: .infinity, minHeight: Theme.tapTarget, alignment: .leading)
                            .padding(.horizontal, 14)
                            .background(Theme.surfaceHigh)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
                    }

                    HourStepper(title: "Straight Time", text: $vm.straightText)
                    HourStepper(title: "Overtime (1.5x)", text: $vm.overtimeText)
                    HourStepper(title: "Double Time (2x)", text: $vm.doubleText)

                    Toggle(isOn: $vm.perDiemReceived) {
                        Text("Got per diem this day")
                            .font(Theme.body()).foregroundStyle(Theme.textPrimary)
                    }
                    .tint(Theme.accent)
                    .frame(minHeight: Theme.tapTarget)

                    MissedMealsStepper(count: $vm.mealsMissed)

                    // Notes + prominent voice button
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Notes")
                        TextField("What happened on the job…", text: $vm.notes, axis: .vertical)
                            .font(Theme.body())
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(2...5)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.surfaceHigh)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.corner))

                        voiceButton

                        if let err = vm.speech.errorMessage {
                            Text(err).font(Theme.body(14)).foregroundStyle(Theme.danger)
                        }
                    }

                    if let error = vm.errorMessage {
                        Text(error).font(Theme.body(15)).foregroundStyle(Theme.danger)
                    }

                    Button {
                        if vm.save(context: context) { dismiss() }
                    } label: { Text("Save Day") }
                        .buttonStyle(.bfc)
                }
                .padding(Theme.pad)
            }
            .bfcBackground()
            .navigationTitle("Log Hours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { vm.speech.stop(); dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .onChange(of: vm.speech.transcript) { vm.syncTranscript() }
        }
    }

    /// Big, obvious mic button — turns red while recording.
    private var voiceButton: some View {
        Button {
            Task { await vm.toggleVoice() }
        } label: {
            Label(vm.isRecording ? "Stop & Use Voice" : "Dictate Notes",
                  systemImage: vm.isRecording ? "stop.fill" : "mic.fill")
                .font(Theme.body(18))
        }
        .buttonStyle(.bfc(fill: vm.isRecording ? Theme.danger : Theme.accent,
                          textColor: vm.isRecording ? .white : .black))
    }
}

/// Whole-number stepper for missed meals (meal-penalty tracking).
private struct MissedMealsStepper: View {
    @Binding var count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Missed Meals (meal penalty)")
            HStack(spacing: 12) {
                button("minus") { count = max(0, count - 1) }
                Text("\(count)")
                    .font(Theme.headline(24))
                    .foregroundStyle(count > 0 ? Theme.danger : Theme.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: Theme.tapTarget)
                    .background(Theme.surfaceHigh)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
                button("plus") { count += 1 }
            }
            Text(count > 0
                 ? "BFL will check if you're owed a meal penalty for these."
                 : "How many times you were NOT fed on time per the contract.")
                .font(Theme.body(13))
                .foregroundStyle(Theme.textMuted)
        }
    }

    private func button(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: Theme.tapTarget, height: Theme.tapTarget)
                .background(Theme.surfaceHigh)
                .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
        }
    }
}

/// A number field with big +/- buttons for hours.
private struct HourStepper: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: title)
            HStack(spacing: 12) {
                stepButton("minus") { adjust(-0.5) }
                TextField("0", text: $text)
                    .font(Theme.headline(24))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .keyboardType(.decimalPad)
                    .frame(maxWidth: .infinity, minHeight: Theme.tapTarget)
                    .background(Theme.surfaceHigh)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
                stepButton("plus") { adjust(0.5) }
            }
        }
    }

    private func stepButton(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: Theme.tapTarget, height: Theme.tapTarget)
                .background(Theme.surfaceHigh)
                .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
        }
    }

    private func adjust(_ delta: Double) {
        let current = Double(text) ?? 0
        text = max(0, current + delta).asHours
    }
}
