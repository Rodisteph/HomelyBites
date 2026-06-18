import SwiftUI

struct RootView: View {
    @Environment(SessionViewModel.self) private var session

    var body: some View {
        @Bindable var session = session
        Group {
            if session.isBootstrapping {
                ProgressView("Chargement...")
            } else if session.isAuthenticated {
                TabView {
                    NavigationStack { MealListView() }
                        .tabItem { Label("Repas", systemImage: "fork.knife") }

                    if session.appUser?.role == .client {
                        NavigationStack { OrdersView() }
                            .tabItem { Label("Commandes", systemImage: "cart") }
                    }

                    if session.appUser?.role == .host {
                        NavigationStack { HostDashboardView() }
                            .tabItem { Label("Host", systemImage: "house") }
                    }

                    NavigationStack { SettingsView() }
                        .tabItem { Label("Profil", systemImage: "gear") }
                }
            } else {
                AuthView()
            }
        }
        .errorAlert(message: $session.globalErrorMessage)
    }
}
