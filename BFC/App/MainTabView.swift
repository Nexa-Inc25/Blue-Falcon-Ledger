import SwiftUI

/// Bottom tab bar — the only navigation chrome in the app. Three tabs per the spec.
struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                HomeView()
            }
            Tab("Employers", systemImage: "building.2.fill") {
                EmployerListView()
            }
            Tab("My Hours & Pay", systemImage: "clock.fill") {
                HoursPayView()
            }
            Tab("Credentials", systemImage: "person.text.rectangle.fill") {
                CredentialsView()
            }
        }
        .tint(Theme.accent)
    }
}
