import SwiftUI
import SwiftData

/// "My Hours & Pay" tab. Centered on the current employer: log hours, upload docs,
/// and analyze pay periods.
struct HoursPayView: View {
    @Environment(\.modelContext) private var context
    @Query private var employers: [Employer]
    @State private var vm = HoursPayViewModel()
    @State private var showingLogHours = false
    @State private var showingImporter = false
    @State private var showingCamera = false

    private var current: Employer? { employers.first(where: { $0.isCurrent }) }

    var body: some View {
        NavigationStack {
            Group {
                if let employer = current {
                    content(for: employer)
                } else {
                    ScrollView {
                        Card {
                            EmptyHint(
                                systemImage: "bolt.fill",
                                title: "Set a current employer",
                                message: "Pick who you're working for on the Employers tab to start logging hours and pay."
                            )
                        }
                        .padding(Theme.pad)
                    }
                }
            }
            .bfcBackground()
            .navigationTitle("Hours & Pay")
            .navigationDestination(for: PayPeriod.self) { period in
                if let employer = current {
                    AnalysisView(payPeriod: period, employer: employer)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    @ViewBuilder
    private func content(for employer: Employer) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(employer.name)
                    .font(Theme.title(24)).foregroundStyle(Theme.textPrimary)

                // Log hours (primary action)
                Button { showingLogHours = true } label: {
                    Label("Log Today's Hours", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.bfc)

                // This period summary
                summary(for: employer)

                // Recent days
                recentDays(for: employer)

                // Documents
                documents(for: employer)

                // Pay periods + analysis
                payPeriods(for: employer)
            }
            .padding(Theme.pad)
        }
        .sheet(isPresented: $showingLogHours) { LogHoursView(employer: employer) }
        .importFile(isPresented: $showingImporter,
                    onError: { vm.statusMessage = $0 }) { file in
            Task { await vm.upload(file, kind: vm.pendingKind, employer: employer, context: context) }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { file in
                Task { await vm.upload(file, kind: vm.pendingKind, employer: employer, context: context) }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: Sections

    private func summary(for employer: Employer) -> some View {
        let days = employer.workDays
        let st = days.reduce(0) { $0 + $1.straightHours }
        let ot = days.reduce(0) { $0 + $1.overtimeHours }
        let dt = days.reduce(0) { $0 + $1.doubleHours }
        let pd = days.filter(\.perDiemReceived).count
        return Card {
            HStack {
                StatPill(label: "Straight", value: st.asHours + "h")
                Spacer()
                StatPill(label: "OT", value: ot.asHours + "h")
                Spacer()
                StatPill(label: "Double", value: dt.asHours + "h")
                Spacer()
                StatPill(label: "PD Days", value: "\(pd)")
            }
        }
    }

    @ViewBuilder
    private func recentDays(for employer: Employer) -> some View {
        let recent = employer.workDays.sorted { $0.date > $1.date }.prefix(8)
        if !recent.isEmpty {
            SectionHeader(title: "Recent Days")
            VStack(spacing: 8) {
                ForEach(Array(recent)) { day in
                    Card(padding: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(day.date.shortLabel)
                                    .font(Theme.body(16)).foregroundStyle(Theme.textPrimary)
                                if !day.notes.isEmpty {
                                    Text(day.notes).font(Theme.body(13))
                                        .foregroundStyle(Theme.textMuted).lineLimit(1)
                                }
                            }
                            Spacer()
                            Text("\(day.totalHours.asHours)h")
                                .font(Theme.headline(18)).foregroundStyle(Theme.accent)
                        }
                    }
                }
            }
        }
    }

    private func documents(for employer: Employer) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Documents")
            Menu {
                ForEach(PayDocumentKind.allCases) { kind in
                    Button {
                        vm.pendingKind = kind
                        showingImporter = true
                    } label: { Label(kind.rawValue, systemImage: kind.systemImage) }
                }
            } label: {
                Label(vm.isUploading ? "Uploading…" : "Upload a Document", systemImage: "arrow.up.doc")
            }
            .buttonStyle(.bfcOutline)
            .disabled(vm.isUploading)

            // Camera capture — only shows on a real device with a camera.
            if cameraIsAvailable {
                Menu {
                    ForEach(PayDocumentKind.allCases) { kind in
                        Button {
                            vm.pendingKind = kind
                            showingCamera = true
                        } label: { Label(kind.rawValue, systemImage: kind.systemImage) }
                    }
                } label: {
                    Label("Take a Photo", systemImage: "camera.fill")
                }
                .buttonStyle(.bfcOutline)
                .disabled(vm.isUploading)
            }

            if let status = vm.statusMessage {
                Text(status).font(Theme.body(14)).foregroundStyle(Theme.textSecondary)
            }

            ForEach(employer.documents.sorted { $0.importedAt > $1.importedAt }) { doc in
                Card(padding: 12) {
                    HStack {
                        Image(systemName: doc.kind.systemImage).foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(doc.kind.rawValue).font(Theme.body(15)).foregroundStyle(Theme.textPrimary)
                            Text(doc.fileName).font(Theme.body(13))
                                .foregroundStyle(Theme.textMuted).lineLimit(1)
                        }
                        Spacer()
                        Button {
                            vm.deleteDocument(doc, context: context)
                        } label: {
                            Image(systemName: "trash").foregroundStyle(Theme.danger)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func payPeriods(for employer: Employer) -> some View {
        SectionHeader(title: "Pay Periods")
        Button {
            if let period = vm.createPeriodFromUnassignedDays(employer: employer, context: context) {
                // Navigation handled by tapping the new row; surface a hint.
                vm.statusMessage = "Created a pay period from your logged days. Tap it below to analyze."
                _ = period
            }
        } label: {
            Label("New Pay Period from Logged Days", systemImage: "calendar.badge.plus")
        }
        .buttonStyle(.bfcOutline)

        let periods = employer.payPeriods.sorted { $0.startDate > $1.startDate }
        if periods.isEmpty {
            Text("No pay periods yet. Log your hours, then create one to analyze.")
                .font(Theme.body(14)).foregroundStyle(Theme.textMuted)
        } else {
            ForEach(periods) { period in
                NavigationLink(value: period) {
                    PayPeriodRow(period: period)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct PayPeriodRow: View {
    let period: PayPeriod
    var body: some View {
        Card(padding: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(period.startDate.rangeLabel) – \(period.endDate.rangeLabel)")
                        .font(Theme.body(16)).foregroundStyle(Theme.textPrimary)
                    Text("\(period.totalHours.asHours)h • \(period.perDiemDays) PD days")
                        .font(Theme.body(13)).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if let result = period.analysisResult {
                    Image(systemName: result.verdict.systemImage)
                        .foregroundStyle(result.verdict.color)
                } else {
                    Image(systemName: "chevron.right").foregroundStyle(Theme.textMuted)
                }
            }
        }
    }
}
