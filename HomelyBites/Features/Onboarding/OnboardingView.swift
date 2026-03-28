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
            HBTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                BrandLogoView(size: 80)
                    .padding(.bottom, 8)

                Text("HomelyBites")
                    .font(HBTheme.Font.display(36))
                    .foregroundStyle(HBTheme.Colors.text)
                    .padding(.bottom, 40)

                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        onboardingPageView(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 220)

                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? HBTheme.Colors.primary : HBTheme.Colors.border)
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }
                .padding(.top, 20)

                Spacer()

                VStack(spacing: 12) {
                    if currentPage < pages.count - 1 {
                        PrimaryButton(title: "Suivant") {
                            withAnimation {
                                currentPage += 1
                            }
                        }

                        Button("Passer") {
                            hasSeenOnboarding = true
                        }
                        .font(HBTheme.Font.body(14, weight: .medium))
                        .foregroundStyle(HBTheme.Colors.textSecondary)
                    } else {
                        PrimaryButton(title: "Commencer") {
                            hasSeenOnboarding = true
                        }
                    }
                }
                .padding(.horizontal, HBTheme.Spacing.screen)
                .padding(.bottom, 48)
            }
        }
    }

    private func onboardingPageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 20) {
            Image(systemName: page.icon)
                .font(.system(size: 56))
                .foregroundStyle(HBTheme.Colors.primary)

            Text(page.title)
                .font(HBTheme.Font.title(24))
                .foregroundStyle(HBTheme.Colors.text)

            Text(page.description)
                .font(HBTheme.Font.body(16))
                .foregroundStyle(HBTheme.Colors.textSecondary)
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
