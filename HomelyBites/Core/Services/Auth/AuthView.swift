import SwiftUI
import UIKit

struct AuthView: View {
    @StateObject private var viewModel: AuthViewModel

    init(authService: AuthService = AuthService()) {
        _viewModel = StateObject(wrappedValue: AuthViewModel(authService: authService))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    onboardingHero

                    VStack(spacing: HBMetrics.Spacing.m) {
                        Picker("Mode", selection: $viewModel.mode) {
                            ForEach(AuthViewModel.Mode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        if viewModel.mode == .signUp {
                            TextField("Nom complet", text: $viewModel.fullName)
                                .textInputAutocapitalization(.words)
                                .hbInputStyle()

                            Picker("Role", selection: $viewModel.selectedRole) {
                                ForEach(UserRole.allCases) { role in
                                    Text(role.displayTitle).tag(role)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: HBMetrics.Radius.input, style: .continuous)
                                    .fill(HBColors.warmWhite)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: HBMetrics.Radius.input, style: .continuous)
                                    .stroke(HBColors.border, lineWidth: 1)
                            )
                        }

                        TextField("Email", text: $viewModel.email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .hbInputStyle()

                        SecureField("Mot de passe", text: $viewModel.password)
                            .hbInputStyle()

                        if viewModel.mode == .signIn {
                            HStack {
                                Spacer()
                                Button("Mot de passe oublie ?") {
                                    Task {
                                        await viewModel.sendPasswordReset()
                                    }
                                }
                                .font(HBTypography.label(size: 13, weight: .semibold))
                                .foregroundStyle(HBColors.terracotta)
                                .disabled(viewModel.isLoading)
                            }
                        }

                        PrimaryButton(
                            title: viewModel.mode.actionTitle,
                            isLoading: viewModel.isLoading,
                            isDisabled: viewModel.isLoading
                        ) {
                            Task {
                                await viewModel.submit()
                            }
                        }

                        SecondaryButton(title: "Continuer avec Google", icon: "globe") {
                            Task {
                                await signInWithGoogleTapped()
                            }
                        }
                        .disabled(viewModel.isLoading)

                        if let infoMessage = viewModel.infoMessage {
                            HStack(spacing: HBMetrics.Spacing.xs) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(HBColors.success)
                                Text(infoMessage)
                                    .font(HBTypography.label(size: 12))
                                    .foregroundStyle(HBColors.success)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(HBMetrics.horizontalPadding)
                    .padding(.top, HBMetrics.Spacing.l)
                    .padding(.bottom, HBMetrics.Spacing.xl)
                    .background(
                        RoundedRectangle(cornerRadius: HBMetrics.Radius.card, style: .continuous)
                            .fill(HBColors.cream)
                            .ignoresSafeArea(edges: .bottom)
                    )
                    .offset(y: -HBMetrics.Spacing.m)
                }
            }
            .background(HBColors.charcoal.ignoresSafeArea())
            .navigationBarHidden(true)
            .alert(
                "Erreur",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                ),
                actions: {
                    Button("OK", role: .cancel) {}
                },
                message: {
                    Text(viewModel.errorMessage ?? "")
                }
            )
        }
    }

    private var onboardingHero: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [HBColors.charcoal, HBColors.terracottaDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(HBColors.terracotta.opacity(0.26))
                .frame(width: 220, height: 220)
                .offset(x: 120, y: -80)

            Circle()
                .fill(HBColors.sage.opacity(0.22))
                .frame(width: 180, height: 180)
                .offset(x: -80, y: 90)

            VStack(alignment: .leading, spacing: HBMetrics.Spacing.s) {
                HStack(spacing: HBMetrics.Spacing.s) {
                    Text("🍽️")
                        .font(.system(size: 30))
                    Text("HomelyBites")
                        .font(HBTypography.display(size: 42))
                        .foregroundStyle(.white)
                }

                Text("Repas faits maison, en toute confiance")
                    .font(HBTypography.body(size: 16, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.88))
            }
            .padding(HBMetrics.horizontalPadding)
            .padding(.bottom, HBMetrics.Spacing.xl)
        }
        .frame(height: 280)
    }

    private func signInWithGoogleTapped() async {
        guard let presenting = rootViewController() else {
            viewModel.errorMessage = "Impossible d'ouvrir Google Sign-In. Reessaie."
            return
        }

        await viewModel.signInWithGoogle(presenting: presenting)
    }

    private func rootViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let activeScene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        guard let root = activeScene?.windows.first(where: \.isKeyWindow)?.rootViewController else {
            return nil
        }
        return root.hbTopMostViewController()
    }
}

private extension UIViewController {
    func hbTopMostViewController() -> UIViewController {
        if let presentedViewController = presentedViewController {
            return presentedViewController.hbTopMostViewController()
        }
        if let navigationController = self as? UINavigationController {
            return navigationController.visibleViewController?.hbTopMostViewController() ?? navigationController
        }
        if let tabBarController = self as? UITabBarController {
            return tabBarController.selectedViewController?.hbTopMostViewController() ?? tabBarController
        }
        return self
    }
}

private extension View {
    func hbInputStyle() -> some View {
        self
            .font(HBTypography.body(size: 15))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: HBMetrics.Radius.input, style: .continuous)
                    .fill(HBColors.warmWhite)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HBMetrics.Radius.input, style: .continuous)
                    .stroke(HBColors.border, lineWidth: 1)
            )
    }
}
