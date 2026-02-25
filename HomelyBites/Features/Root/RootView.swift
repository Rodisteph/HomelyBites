import SwiftUI

struct RootView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var session: SessionViewModel

    var body: some View {
        Group {
            if session.isBootstrapping {
                SplashView()
            } else if session.isAuthenticated {
                authenticatedTabs
            } else {
                AuthView(authService: container.authService)
            }
        }
        .background(AppColors.cream.ignoresSafeArea())
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

            NavigationStack {
                MapView()
            }
            .tabItem {
                Label("Map", systemImage: "map")
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
                ProfileView()
            }
            .tabItem {
                Label("Profil", systemImage: "person.crop.circle")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
        .tint(AppColors.terracotta)
    }
}

// MARK: - Splash View
private struct SplashView: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                colors: [AppColors.cream, AppColors.creamDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                // Brand Logo with Animation
                BrandLogoView(size: 120)
                    .scaleEffect(scale)
                    .opacity(opacity)

                // Brand Name
                VStack(spacing: 8) {
                    Text("HomelyBites")
                        .font(.cormorantDisplay(42, weight: .semibold))
                        .foregroundStyle(AppColors.charcoal)

                    Text("Cuisine locale, faite maison")
                        .font(.bodyLarge)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .opacity(opacity)

                // Loading Indicator
                ProgressView()
                    .tint(AppColors.terracotta)
                    .scaleEffect(1.2)
                    .padding(.top, 20)
                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
            }
            withAnimation(.easeIn(duration: 0.4)) {
                opacity = 1.0
            }
        }
    }
}
