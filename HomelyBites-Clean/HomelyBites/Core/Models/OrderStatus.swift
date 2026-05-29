import Foundation

// 📦 Déplacé depuis Features/Orders/ — c'est un modèle, pas une feature
enum OrderStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case confirmed
    case cancelled
    case rejected

    var id: String { rawValue }
    var displayTitle: String { rawValue.capitalized }
}
