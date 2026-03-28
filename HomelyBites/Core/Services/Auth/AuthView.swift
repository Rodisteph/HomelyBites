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

                    VStack(spacing: HBTheme.Spacing.m) {
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
                                RoundedRectangle(cornerRadius: HBTheme.Radius.input, style: .continuous)
                                    .fill(HBTheme.Colors.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: HBTheme.Radius.input, style: .continuous)
                                    .stroke(HBTheme.Colors.border, lineWidth: 1)
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
                                    Task { await viewModel.sendPasswordReset() }
                                }
                                .font(HBTheme.Font.label(13, weight: .semibold))
                                .foregroundStyle(HBTheme.Colors.primary)
                                .disabled(viewModel.isLoading)
                            }
                        }

                        PrimaryButton(
                            title: viewModel.mode.actionTitle,
                            isLoading: viewModel.isLoading,
                            isDisabled: viewModel.isLoading
                        ) {
                            Task { await viewModel.submit() }
                        }

                        SecondaryButton(title: "Continuer avec Google", icon: "globe") {
                            Task { await signInWithGoogleTapped() }
                        }
                        .disabled(viewModel.isLoading)

                        if let infoMessage = viewModel.infoMessage {
                            HStack(spacing: HBTheme.Spacing.xs) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(HBTheme.Colors.success)
                                Text(infoMessage)
                                    .font(HBTheme.Font.label(12))
                                    .foregroundStyle(HBTheme.Colors.success)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(HBTheme.Spacing.screen)
                    .padding(.top, HBTheme.Spacing.l)
                    .padding(.bottom, HBTheme.Spacing.xl)
                    .background(
                        RoundedRectangle(cornerRadius: HBTheme.Radius.card, style: .continuous)
                            .fill(HBTheme.Colors.background)
                            .ignoresSafeArea(edges: .bottom)
                    )
                    .offset(y: -HBTheme.Spacing.m)
                }
            }
            .background(HBTheme.Colors.text.ignoresSafeArea())
            .navigationBarHidden(true)
            .alert(
                "Erreur",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                ),
                actions: { Button("OK", role: .cancel) {} },
                message: { Text(viewModel.errorMessage ?? "") }
            )
        }
    }

    // MARK: - Hero

    private var onboardingHero: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [HBTheme.Colors.text, HBTheme.Colors.primaryDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(HBTheme.Colors.primary.opacity(0.26))
                .frame(width: 220, height: 220)
                .offset(x: 120, y: -80)

            Circle()
                .fill(HBTheme.Colors.sage.opacity(0.22))
                .frame(width: 180, height: 180)
                .offset(x: -80, y: 90)

            VStack(alignment: .leading, spacing: HBTheme.Spacing.s) {
                Text("HomelyBites")
                    .font(HBTheme.Font.display(42))
                    .foregroundStyle(.white)

                Text("Repas faits maison, en toute confiance")
                    .font(HBTheme.Font.body(16, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.88))
            }
            .padding(HBTheme.Spacing.screen)
            .padding(.bottom, HBTheme.Spacing.xl)
        }
        .frame(height: 280)
    }

    // MARK: - Google Sign-In

    private func signInWithGoogleTapped() async {
        guard let presenting = rootViewController() else {
            viewModel.errorMessage = "Impossible d'ouvrir Google Sign-In."
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
        if let nav = self as? UINavigationController {
            return nav.visibleViewController?.hbTopMostViewController() ?? nav
        }
        if let tab = self as? UITabBarController {
            return tab.selectedViewController?.hbTopMostViewController() ?? tab
        }
        return self
    }
}
