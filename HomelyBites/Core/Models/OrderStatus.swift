import Foundation

enum OrderStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case confirmed
    case cancelled
    case rejected

    var id: String { rawValue }
    var displayTitle: String { rawValue.capitalized }
}
