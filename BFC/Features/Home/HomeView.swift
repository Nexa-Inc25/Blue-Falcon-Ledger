import SwiftUI
import SwiftData

/// Home: current employer big at top, past employers list, big Add button.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Employer.createdAt, order: .reverse) private var employers: [Employer]
    @State private var vm = HomeViewModel()
    @State private var showingAdd = false

    private var split: (current: Employer?, past: [Employer]) { vm.split(employers) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Current employer
                    SectionHeader(title: "Current Employer")
                    if let current = split.current {
                        NavigationLink(value: current) {
                            CurrentEmployerCard(employer: current)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Card {
                            EmptyHint(
                                systemImage: "bolt.fill",
                                title: "No current employer",
                                message: "Add who you're working for to start tracking hours and pay."
                            )
                        }
                    }

                    // Past employers
                    if !split.past.isEmpty {
                        SectionHeader(title: "Past Employers")
                        VStack(spacing: 10) {
                            ForEach(split.past) { employer in
                                NavigationLink(value: employer) {
                                    PastEmployerRow(employer: employer)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Add button
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add Employer", systemImage: "plus")
                    }
                    .buttonStyle(.bfc)
                    .padding(.top, 4)
                }
                .padding(Theme.pad)
            }
            .bfcBackground()
            .navigationTitle("Blue Falcon Ledger")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Employer.self) { EmployerDetailView(employer: $0) }
            .sheet(isPresented: $showingAdd) {
                AddEditEmployerView(employer: nil)
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { SettingsView() } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - Cards

private struct CurrentEmployerCard: View {
    let employer: Employer

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(employer.name)
                        .font(Theme.title(26))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Theme.textMuted)
                }
                if !employer.ibewLocal.isEmpty {
                    Label("IBEW Local \(employer.ibewLocal)", systemImage: "person.3.fill")
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.textSecondary)
                }
                HStack(spacing: 16) {
                    StatPill(label: "Per Diem", value: employer.perDiemRate.asMoney + "/day")
                    StatPill(label: "Days Logged", value: "\(employer.workDays.count)")
                }
                Label(
                    employer.hasAgreement ? "Labor agreement loaded" : "No labor agreement yet",
                    systemImage: employer.hasAgreement ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
                )
                .font(Theme.body(14))
                .foregroundStyle(employer.hasAgreement ? Theme.good : Theme.warn)
            }
        }
    }
}

private struct PastEmployerRow: View {
    let employer: Employer

    var body: some View {
        Card(padding: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(employer.name)
                        .font(Theme.headline(18))
                        .foregroundStyle(Theme.textPrimary)
                    if !employer.ibewLocal.isEmpty {
                        Text("IBEW Local \(employer.ibewLocal)")
                            .font(Theme.body(14))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.textMuted)
            }
        }
    }
}

struct StatPill: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Theme.textMuted)
            Text(value)
                .font(Theme.headline(18))
                .foregroundStyle(Theme.accent)
        }
    }
}
