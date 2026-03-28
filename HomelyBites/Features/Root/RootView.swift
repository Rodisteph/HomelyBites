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
        .hbBackground()
        .alert(
            "Erreur",
            isPresented: Binding(
                get: { session.globalErrorMessage != nil },
                set: { if !$0 { session.globalErrorMessage = nil } }
            ),
            actions: { Button("OK", role: .cancel) {} },
            message: { Text(session.globalErrorMessage ?? "") }
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
                    Label("Commandes", systemImage: "bag")
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
                    Label("Dashboard", systemImage: "chart.bar")
                }
            }

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profil", systemImage: "person.crop.circle")
            }
        }
        .tint(HBTheme.Colors.primary)
    }
}

// MARK: - Splash View

private struct SplashView: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [HBTheme.Colors.background, HBTheme.Colors.border],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                BrandLogoView(size: 120)
                    .scaleEffect(scale)
                    .opacity(opacity)

                VStack(spacing: 8) {
                    Text("HomelyBites")
                        .font(HBTheme.Font.display(42))
                        .foregroundStyle(HBTheme.Colors.text)

                    Text("Cuisine locale, faite maison")
                        .font(HBTheme.Font.body())
                        .foregroundStyle(HBTheme.Colors.textSecondary)
                }
                .opacity(opacity)

                ProgressView()
                    .tint(HBTheme.Colors.primary)
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
