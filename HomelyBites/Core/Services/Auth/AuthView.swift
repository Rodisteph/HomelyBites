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
                VStack(spacing: 18) {
                    VStack(spacing: 10) {
                        BrandLogoView(size: 86)
                        Text("HomelyBites")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppColors.textPrimary)
                        Text("Repas faits maison, en toute confiance")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(.top, 16)

                    Picker("Mode", selection: $viewModel.mode) {
                        ForEach(AuthViewModel.Mode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if viewModel.mode == .signUp {
                        TextField("Nom complet", text: $viewModel.fullName)
                            .textInputAutocapitalization(.words)
                            .appTextFieldStyle()

                        Picker("Role", selection: $viewModel.selectedRole) {
                            ForEach(UserRole.allCases) { role in
                                Text(role.displayTitle).tag(role)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: AppMetrics.controlCornerRadius, style: .continuous)
                                .fill(AppColors.surface)
                        )
                    }

                    TextField("Email", text: $viewModel.email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .appTextFieldStyle()

                    SecureField("Mot de passe", text: $viewModel.password)
                        .appTextFieldStyle()

                    Button {
                        Task {
                            await viewModel.submit()
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(viewModel.mode.actionTitle)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(isLoading: viewModel.isLoading))
                    .disabled(viewModel.isLoading)

                    Button {
                        Task {
                            await signInWithGoogleTapped()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "globe")
                            Text("Continuer avec Google")
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .foregroundStyle(AppColors.textPrimary)
                    .background(
                        RoundedRectangle(cornerRadius: AppMetrics.controlCornerRadius, style: .continuous)
                            .fill(AppColors.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppMetrics.controlCornerRadius, style: .continuous)
                            .stroke(AppColors.textSecondary.opacity(0.2), lineWidth: 1)
                    )
                    .disabled(viewModel.isLoading)
                }
                .padding(AppMetrics.horizontalPadding)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Connexion")
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
