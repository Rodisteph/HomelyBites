import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var mode: Mode = .signIn
    @Published var fullName = ""
    @Published var email = ""
    @Published var password = ""
    @Published var selectedRole: UserRole = .client
    @Published var isLoading = false
    @Published var errorMessage: String?

    enum Mode: String, CaseIterable, Identifiable {
        case signIn
        case signUp

        var id: String { rawValue }

        var title: String {
            switch self {
            case .signIn: return "Connexion"
            case .signUp: return "Inscription"
            }
        }

        var actionTitle: String {
            switch self {
            case .signIn: return "Se connecter"
            case .signUp: return "Creer un compte"
            }
        }
    }

    private let authService = AuthService()

    func submit() async {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Email requis."
            return
        }

        guard password.count >= 6 else {
            errorMessage = "Mot de passe: minimum 6 caracteres."
            return
        }

        if mode == .signUp {
            guard !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                errorMessage = "Nom complet requis."
                return
            }
        }

        isLoading = true
        defer { isLoading = false }

        do {
            switch mode {
            case .signIn:
                try await authService.signIn(email: email, password: password)
            case .signUp:
                try await authService.signUp(
                    email: email,
                    password: password,
                    fullName: fullName,
                    role: selectedRole
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
