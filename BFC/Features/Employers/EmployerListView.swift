import SwiftUI
import SwiftData

/// Employers tab: every employer, current one flagged, with add + swipe-to-delete.
struct EmployerListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Employer.createdAt, order: .reverse) private var employers: [Employer]
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if employers.isEmpty {
                    ScrollView {
                        Card {
                            EmptyHint(
                                systemImage: "building.2",
                                title: "No employers yet",
                                message: "Add the outfits you've worked for to track hours, pay, and agreements."
                            )
                        }
                        .padding(Theme.pad)
                    }
                } else {
                    List {
                        ForEach(employers) { employer in
                            NavigationLink(value: employer) {
                                EmployerRow(employer: employer)
                            }
                            .listRowBackground(Theme.surface)
                            .listRowSeparatorTint(Theme.border)
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .bfcBackground()
            .navigationTitle("Employers")
            .navigationDestination(for: Employer.self) { EmployerDetailView(employer: $0) }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus").foregroundStyle(Theme.accent)
                    }
                }
            }
            .sheet(isPresented: $showingAdd) { AddEditEmployerView(employer: nil) }
        }
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets { context.delete(employers[index]) }
        try? context.save()
    }
}

private struct EmployerRow: View {
    let employer: Employer
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: employer.isCurrent ? "bolt.fill" : "building.2")
                .font(.system(size: 22))
                .foregroundStyle(employer.isCurrent ? Theme.accent : Theme.textMuted)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(employer.name)
                    .font(Theme.headline(18)).foregroundStyle(Theme.textPrimary)
                HStack(spacing: 8) {
                    if employer.isCurrent {
                        Text("CURRENT")
                            .font(.system(size: 10, weight: .heavy))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.accent).foregroundStyle(.black)
                            .clipShape(Capsule())
                    }
                    if !employer.ibewLocal.isEmpty {
                        Text("Local \(employer.ibewLocal)")
                            .font(Theme.body(14)).foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}
