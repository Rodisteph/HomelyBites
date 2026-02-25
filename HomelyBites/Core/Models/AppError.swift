import Foundation

enum AppError: LocalizedError {
    case authFailed(String)
    case firestoreError(String)
    case stripeError(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .authFailed(let msg):
            return "Auth: \(msg)"
        case .firestoreError(let msg):
            return "Firestore: \(msg)"
        case .stripeError(let msg):
            return "Stripe: \(msg)"
        case .unknown:
            return "Une erreur inconnue est survenue"
        }
    }
}

extension AppError {
    static var invalidResponse: AppError {
        .firestoreError("Reponse serveur invalide.")
    }

    static var missingAuth: AppError {
        .authFailed("Session non authentifiee.")
    }

    static var missingUserProfile: AppError {
        .firestoreError("Profil utilisateur introuvable.")
    }

    static var hostPaymentsNotReady: AppError {
        .stripeError("Ce host n'a pas encore active ses paiements Stripe.")
    }

    static func invalidInput(_ message: String) -> AppError {
        .firestoreError(message)
    }

    static var stripePublishableKeyMissing: AppError {
        .stripeError("Cle Stripe publishable manquante dans Info.plist.")
    }
}
