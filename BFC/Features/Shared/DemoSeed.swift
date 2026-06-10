#if DEBUG
import SwiftUI
import SwiftData

/// DEBUG-only sample data + screen router used to capture App Store screenshots in the
/// simulator. Never compiled into Release builds. Drive it with launch arguments, e.g.
/// `-demoHome`, `-demoAnalysis`, `-demoCredentials`, `-demoChat`.
enum DemoSeed {
    static func populate(_ context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Employer>())) ?? []
        guard existing.isEmpty else { return }
        let cal = Calendar.current

        let employer = Employer(name: "Brotherhood Line Construction", ibewLocal: "1245",
                                perDiemRate: 120, isCurrent: true)
        context.insert(employer)

        let agreement = LaborAgreement(
            fileName: "Local 1245 Outside Agreement.pdf",
            fullText: """
            ARTICLE 5 — OVERTIME AND DOUBLE TIME
            All work performed on Sundays and recognized holidays shall be paid at double the regular rate.
            ARTICLE 8 — SUBSISTENCE
            Employees shall receive a subsistence (per diem) of $120.00 per day worked beyond 70 miles from the shop.
            APPENDIX A — WAGE SCHEDULE
            Journeyman Lineman $58.00/hr. Foreman 1.15x JL. General Foreman 1.20x JL.
            """)
        agreement.employer = employer
        employer.laborAgreement = agreement
        context.insert(agreement)

        var days: [WorkDay] = []
        for i in 1...5 {
            let date = cal.date(byAdding: .day, value: -i, to: .now)!
            let day = WorkDay(date: date, straightHours: 8,
                              overtimeHours: i == 1 ? 0 : 2, doubleHours: i == 1 ? 4 : 0,
                              perDiemReceived: true, mealsMissed: i == 3 ? 1 : 0)
            day.employer = employer
            employer.workDays.append(day)
            context.insert(day)
            days.append(day)
        }

        let period = PayPeriod(startDate: days.last!.date, endDate: days.first!.date,
                               totalPayReceived: 2840)
        period.employer = employer
        for day in days { day.payPeriod = period; period.workDays.append(day) }
        employer.payPeriods.append(period)
        context.insert(period)

        let result = AnalysisResult(
            verdict: .shorted,
            headline: "Shorted 4 hrs double time — about $184 owed",
            detail: "On Sunday you worked 4 hours paid at straight time, but [ARTICLE 5 — OVERTIME AND DOUBLE TIME] says Sunday work is double time. At your $58.00/hr JL rate that's about $184 they owe you. Per diem and the rest of the week check out.",
            amountOwed: 184)
        result.payPeriod = period
        period.analysisResult = result
        context.insert(result)

        let q = ChatMessage(role: .user, content: "What's my per diem on this job?")
        q.agreement = agreement
        let a = ChatMessage(role: .assistant,
                            content: "According to [ARTICLE 8 — SUBSISTENCE], you get $120.00 per day worked when you're more than 70 miles from the shop.",
                            sources: ["ARTICLE 8 — SUBSISTENCE"])
        a.agreement = agreement
        agreement.chatMessages.append(contentsOf: [q, a])
        context.insert(q); context.insert(a)

        let creds = [
            Credential(kind: .firstAidCPR, fileName: "cpr-card.jpg", fileData: Data([0]),
                       expirationDate: cal.date(byAdding: .day, value: 18, to: .now)),
            Credential(kind: .dotPhysical, fileName: "dot-physical.pdf", fileData: Data([0]),
                       expirationDate: cal.date(byAdding: .month, value: 8, to: .now)),
            Credential(kind: .osha10, fileName: "osha10-card.pdf", fileData: Data([0])),
            Credential(kind: .duesReceipt, fileName: "dues-q2.pdf", fileData: Data([0]),
                       expirationDate: cal.date(byAdding: .day, value: -3, to: .now))
        ]
        creds.forEach { context.insert($0) }

        try? context.save()
    }
}

/// Seeds demo data, then shows the screen named by the launch argument for screenshotting.
struct DemoHost: View {
    @Environment(\.modelContext) private var context
    @Query private var employers: [Employer]
    @State private var seeded = false

    var body: some View {
        Group {
            if let employer = employers.first(where: { $0.isCurrent }) ?? employers.first {
                let args = ProcessInfo.processInfo.arguments
                if args.contains("-demoCredentials") {
                    CredentialsView()
                } else if args.contains("-demoAnalysis"), let period = employer.payPeriods.first {
                    NavigationStack { AnalysisView(payPeriod: period, employer: employer) }
                } else if args.contains("-demoChat") {
                    NavigationStack { AgreementChatView(employer: employer) }
                } else {
                    MainTabView() // -demoHome
                }
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .task { if !seeded { DemoSeed.populate(context); seeded = true } }
    }
}
#endif
