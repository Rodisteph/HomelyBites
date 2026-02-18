import SwiftUI

struct RootView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var session: SessionViewModel

    var body: some View {
        Group {
            if session.isBootstrapping {
                ProgressView("Chargement...")
                    .tint(AppColors.primary)
            } else if session.isAuthenticated {
                authenticatedTabs
                    .overlay(alignment: .topTrailing) {
                        BrandLogoView(size: 28)
                            .padding(.top, 6)
                            .padding(.trailing, 10)
                            .allowsHitTesting(false)
                    }
            } else {
                AuthView(authService: container.authService)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
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
                    HostDashboardView(
                        firestoreService: container.firestoreService,
                        functionsService: container.cloudFunctionsService
                    )
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
