import Foundation

enum AppError: LocalizedError {
    case invalidResponse
    case missingAuth
    case missingUserProfile
    case hostPaymentsNotReady
    case invalidInput(String)
    case stripePublishableKeyMissing
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidResponse:           return "Réponse serveur invalide."
        case .missingAuth:               return "Session non authentifiée."
        case .missingUserProfile:        return "Profil utilisateur introuvable."
        case .hostPaymentsNotReady:      return "Ce host n'a pas encore activé ses paiements Stripe."
        case .invalidInput(let message): return message
        case .stripePublishableKeyMissing: return "Clé Stripe publishable manquante dans Info.plist."
        case .unknown:                   return "Une erreur inattendue est survenue."
        }
    }
}
