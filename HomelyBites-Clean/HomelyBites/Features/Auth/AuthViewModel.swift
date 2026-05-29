import Foundation
import Observation

// 🔑 Déplacé depuis Core/Services/Auth/ → Features/Auth/ (c'est une feature, pas un service)
@Observable
@MainActor
final class AuthViewModel {

    enum Mode: String, CaseIterable, Identifiable {
        case signIn, signUp
        var id: String { rawValue }
        var title: String       { self == .signIn ? "Connexion"    : "Inscription" }
        var actionTitle: String { self == .signIn ? "Se connecter" : "Créer un compte" }
    }

    var mode: Mode = .signIn
    var fullName = ""
    var email = ""
    var password = ""
    var selectedRole: UserRole = .client
    var isLoading = false
    var errorMessage: String?

    private let authService = AuthService()

    func submit() async {
        // Validations
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Email requis."; return
        }
        guard password.count >= 6 else {
            errorMessage = "Mot de passe : minimum 6 caractères."; return
        }
        if mode == .signUp {
            guard !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                errorMessage = "Nom complet requis."; return
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
                    email: email, password: password,
                    fullName: fullName, role: selectedRole
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
