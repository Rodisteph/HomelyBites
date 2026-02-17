import Foundation

enum UserRole: String, Codable, CaseIterable, Identifiable {
    case client
    case host

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .client: return "Client"
        case .host: return "Host"
        }
    }
}
