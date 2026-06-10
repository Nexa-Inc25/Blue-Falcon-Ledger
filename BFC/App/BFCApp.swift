import SwiftUI
import SwiftData

@main
struct BFCApp: App {
    /// Single SwiftData container for all domain models.
    let container: ModelContainer
    @State private var session = SessionStore()
    @State private var settings = AppSettings.shared
    @State private var subscriptions = SubscriptionService.shared

    init() {
        container = Self.makeContainer()
    }

    /// Build the SwiftData container safely. We create the Application Support
    /// directory up front (it may not exist on a fresh install / device) and point
    /// the store at an explicit URL there. If the on-disk store can't be opened we
    /// fall back to an in-memory store so the app still launches instead of crashing.
    private static func makeContainer() -> ModelContainer {
        let schema = Schema([
            UserProfile.self,
            Employer.self,
            LaborAgreement.self,
            AgreementChunk.self,
            WorkDay.self,
            PayPeriod.self,
            PayDocument.self,
            ChatMessage.self,
            AnalysisResult.self,
            Credential.self
        ])

        // Ensure Application Support exists before SwiftData tries to write there.
        let fileManager = FileManager.default
        let appSupportURL = URL.applicationSupportDirectory
        try? fileManager.createDirectory(at: appSupportURL,
                                         withIntermediateDirectories: true,
                                         attributes: nil)
        let storeURL = appSupportURL.appending(path: "BFC.store")

        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // Last-resort fallback: keep the app usable for this session.
            let inMemory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            if let container = try? ModelContainer(for: schema, configurations: inMemory) {
                return container
            }
            fatalError("Failed to set up local storage: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(settings)
                .environment(subscriptions)
                .preferredColorScheme(.dark) // Dark mode first.
                .tint(Theme.accent)
                .task { await subscriptions.start() }
        }
        .modelContainer(container)
    }
}
