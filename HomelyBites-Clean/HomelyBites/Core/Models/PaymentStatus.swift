import Foundation

// 📦 Déplacé depuis Features/Orders/ — c'est un modèle, pas une feature
enum PaymentStatus: String, Codable, CaseIterable, Identifiable {
    case requires_payment
    case paid
    case failed
    case refunded

    var id: String { rawValue }
    var displayTitle: String {
        rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
