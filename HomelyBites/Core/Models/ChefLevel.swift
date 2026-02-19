import Foundation

enum ChefLevel: String, Codable, CaseIterable, Identifiable {
    case beginner
    case intermediate
    case advanced

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .beginner:
            return "Debutant"
        case .intermediate:
            return "Intermediaire"
        case .advanced:
            return "Confirme"
        }
    }
}
