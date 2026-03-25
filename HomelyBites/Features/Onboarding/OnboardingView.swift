import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool

    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "fork.knife.circle.fill",
            title: "Repas faits maison",
            description: "Découvrez des repas authentiques préparés par des cuisiniers passionnés près de chez vous."
        ),
        OnboardingPage(
            icon: "person.2.fill",
            title: "Rencontrez vos voisins",
            description: "Partagez un moment convivial autour d'un bon repas chez l'habitant ou à emporter."
        ),
        OnboardingPage(
            icon: "creditcard.fill",
            title: "Paiement sécurisé",
            description: "Payez en toute sécurité avec Apple Pay. Vos transactions sont protégées par Stripe."
        )
    ]

    var body: some View {
        ZStack {
            AppColors.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                BrandLogoView(size: 80)
                    .padding(.bottom, 8)

                Text("HomelyBites")
                    .font(.cormorantDisplay(36, weight: .semibold))
                    .foregroundStyle(AppColors.charcoal)
                    .padding(.bottom, 40)

                // Page Content
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        onboardingPageView(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 220)

                // Page Indicators
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? AppColors.primary : AppColors.border)
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }
                .padding(.top, 20)

                Spacer()

                // Action Buttons
                VStack(spacing: 12) {
                    if currentPage < pages.count - 1 {
                        Button("Suivant") {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button("Passer") {
                            hasSeenOnboarding = true
                        }
                        .font(.dmSans(14, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                    } else {
                        Button("Commencer") {
                            hasSeenOnboarding = true
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
                .padding(.horizontal, AppMetrics.horizontalPadding)
                .padding(.bottom, 48)
            }
        }
    }

    private func onboardingPageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 20) {
            Image(systemName: page.icon)
                .font(.system(size: 56))
                .foregroundStyle(AppColors.primary)

            Text(page.title)
                .font(.headlineLarge)
                .foregroundStyle(AppColors.charcoal)

            Text(page.description)
                .font(.bodyLarge)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .lineSpacing(4)
        }
    }
}

private struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
}
