import Foundation
import FirebaseAuth
import FirebaseFirestore
import UIKit

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var mode: Mode = .signIn
    @Published var fullName = ""
    @Published var email = ""
    @Published var password = ""
    @Published var selectedRole: UserRole = .client
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

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

    private let authService: AuthService

    init(authService: AuthService = AuthService()) {
        self.authService = authService
    }

    func submit() async {
        infoMessage = nil
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
            logSubmitError(error)
            errorMessage = userFacingMessage(for: error)
        }
    }

    func signInWithGoogle(presenting: UIViewController) async {
        infoMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await authService.signInWithGoogle(presenting: presenting)
        } catch {
            logSubmitError(error)
            errorMessage = userFacingMessage(for: error)
        }
    }

    func sendPasswordReset() async {
        infoMessage = nil
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEmail.isEmpty else {
            errorMessage = "Saisis ton email pour reinitialiser le mot de passe."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await authService.sendPasswordReset(email: normalizedEmail)
            infoMessage = "Email de reinitialisation envoye. Verifie ta boite mail."
        } catch {
            logSubmitError(error)
            errorMessage = userFacingMessage(for: error)
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        if let appError = error as? AppError {
            return appError.localizedDescription
        }

        let nsError = error as NSError

        if nsError.domain == AuthErrorDomain,
           let authCode = AuthErrorCode(rawValue: nsError.code)?.code {
            switch authCode {
            case .wrongPassword:
                return "Mot de passe incorrect."
            case .userNotFound:
                return "Aucun compte trouve pour cet email."
            case .invalidCredential:
                return "Email ou mot de passe invalide."
            case .userDisabled:
                return "Ce compte est desactive. Contacte le support."
            case .emailAlreadyInUse:
                return "Cet email est deja utilise."
            case .invalidEmail:
                return "Adresse email invalide."
            case .weakPassword:
                return "Mot de passe trop faible (minimum 6 caracteres)."
            case .networkError:
                return "Probleme reseau. Verifie ta connexion et reessaie."
            case .tooManyRequests:
                return "Trop de tentatives. Reessaie dans quelques minutes."
            case .operationNotAllowed:
                return "Inscription email/mot de passe non activee dans Firebase."
            case .appNotAuthorized, .invalidAPIKey:
                return "Configuration Firebase invalide (bundle id ou GoogleService-Info.plist)."
            case .internalError:
                return "Erreur interne Firebase. Verifie la configuration du projet."
            default:
                return nsError.localizedDescription
            }
        }

        if nsError.domain == FirestoreErrorDomain || nsError.domain == "FIRFirestoreErrorDomain" {
            switch nsError.code {
            case 7:
                return "Compte cree mais permission Firestore refusee pour creer le profil."
            case 14:
                return "Firestore est indisponible. Reessaie dans un instant."
            case 16:
                return "Session invalide pendant la creation du profil. Reconnecte-toi."
            default:
                return "Compte cree mais impossible de finaliser le profil utilisateur."
            }
        }

        if nsError.domain == NSURLErrorDomain {
            return "Aucune connexion internet. Reessaie quand le reseau est disponible."
        }

        if nsError.domain == "com.google.GIDSignIn" {
            if nsError.code == -5 {
                return "Connexion Google annulee."
            }
            return "Connexion Google impossible pour le moment."
        }

        return "Une erreur interne est survenue. Reessaie."
    }

    private func logSubmitError(_ error: Error) {
        #if DEBUG
        let nsError = error as NSError
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let masked = maskedEmail(normalizedEmail)
        debugLog("[AuthViewModel][submit] failure mode=\(mode.rawValue) email=\(masked) role=\(selectedRole.rawValue)")
        debugLog("[AuthViewModel][submit] domain=\(nsError.domain) code=\(nsError.code)")
        debugLog("[AuthViewModel][submit] localizedDescription=\(nsError.localizedDescription)")
        debugLog("[AuthViewModel][submit] userInfo=\(nsError.userInfo)")

        for key in [
            "FIRAuthErrorUserInfoNameKey",
            "FIRAuthErrorUserInfoDeserializedResponseKey",
            "FIRAuthErrorUserInfoUpdatedCredentialKey"
        ] {
            if let value = nsError.userInfo[key] {
                debugLog("[AuthViewModel][submit] \(key)=\(value)")
            }
        }

        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            debugLog("[AuthViewModel][submit] underlying.domain=\(underlying.domain) code=\(underlying.code)")
            debugLog("[AuthViewModel][submit] underlying.localizedDescription=\(underlying.localizedDescription)")
            debugLog("[AuthViewModel][submit] underlying.userInfo=\(underlying.userInfo)")
        }

        if let detailedErrors = nsError.userInfo["NSDetailedErrors"] as? [NSError], !detailedErrors.isEmpty {
            for (index, item) in detailedErrors.enumerated() {
                debugLog("[AuthViewModel][submit] detailed[\(index)].domain=\(item.domain) code=\(item.code)")
                debugLog("[AuthViewModel][submit] detailed[\(index)].localizedDescription=\(item.localizedDescription)")
                debugLog("[AuthViewModel][submit] detailed[\(index)].userInfo=\(item.userInfo)")
            }
        }
        #endif
    }

    private func maskedEmail(_ email: String) -> String {
        let parts = email.split(separator: "@", maxSplits: 1).map(String.init)
        guard parts.count == 2 else {
            return "***"
        }
        return "\(parts[0].prefix(2))***@\(parts[1])"
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        NSLog("%@", message)
        #endif
    }
}
