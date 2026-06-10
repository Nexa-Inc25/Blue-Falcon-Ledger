import Foundation
import SwiftData

/// Home dashboard logic: surface the current employer and the rest as history.
@MainActor
@Observable
final class HomeViewModel {
    /// Split a fetched list into (current, past).
    func split(_ employers: [Employer]) -> (current: Employer?, past: [Employer]) {
        let current = employers.first(where: { $0.isCurrent })
        let past = employers
            .filter { $0.id != current?.id }
            .sorted { $0.createdAt > $1.createdAt }
        return (current, past)
    }
}
