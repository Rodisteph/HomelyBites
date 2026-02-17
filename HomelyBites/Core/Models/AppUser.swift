
import Foundation

struct AppUser: Codable, Identifiable {
    var id: String
    var fullName: String
    var role: UserRole
    var stripeAccountId: String?
    var stripeOnboarded: Bool?

    var isHost: Bool {
        role == .host
    }

    var isStripeReady: Bool {
        (stripeAccountId?.isEmpty == false) && (stripeOnboarded == true)
    }
}
