import Foundation

enum PaymentStatus: String, Codable, CaseIterable {
    case requires_payment
    case paid
    case failed
    case refunded

    var displayTitle: String {
        rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
