import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: SessionViewModel

    var body: some View {
        Group {
            if session.isBootstrapping {
                ProgressView("Chargement...")
            } else if session.isAuthenticated {
                authenticatedTabs
            } else {
                AuthView()
            }
        }
        .alert(
            "Erreur",
            isPresented: Binding(
                get: { session.globalErrorMessage != nil },
                set: { if !$0 { session.globalErrorMessage = nil } }
            ),
            actions: {
                Button("OK", role: .cancel) {}
            },
            message: {
                Text(session.globalErrorMessage ?? "")
            }
        )
    }

    private var authenticatedTabs: some View {
        TabView {
            NavigationStack {
                MealListView()
            }
            .tabItem {
                Label("Repas", systemImage: "fork.knife")
            }

            if session.appUser?.role == .client {
                NavigationStack {
                    OrdersView()
                }
                .tabItem {
                    Label("Commandes", systemImage: "cart")
                }
            }

            if session.appUser?.role == .host {
                NavigationStack {
                    HostDashboardView()
                }
                .tabItem {
                    Label("Host", systemImage: "house")
                }
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
    }
}
