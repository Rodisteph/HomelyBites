import Foundation

enum OrderStatus: String, Codable, CaseIterable {
    case pending
    case confirmed
    case cancelled
    case rejected

    var displayTitle: String {
        rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
