
import Foundation

struct AppUser: Codable, Identifiable {
    var id: String
    var displayName: String
    var role: UserRole
    var photoURL: String?
    var bio: String
    var chefLevel: ChefLevel
    var stripeAccountId: String?
    var stripeOnboarded: Bool?
    var stripeStatus: String?

    init(
        id: String,
        fullName: String,
        role: UserRole,
        photoURL: String? = nil,
        bio: String = "",
        chefLevel: ChefLevel = .beginner,
        stripeAccountId: String? = nil,
        stripeOnboarded: Bool? = nil,
        stripeStatus: String? = nil
    ) {
        self.id = id
        self.displayName = fullName
        self.role = role
        self.photoURL = photoURL
        self.bio = bio
        self.chefLevel = chefLevel
        self.stripeAccountId = stripeAccountId
        self.stripeOnboarded = stripeOnboarded
        self.stripeStatus = stripeStatus
    }

    var fullName: String {
        get { displayName }
        set { displayName = newValue }
    }

    var isHost: Bool {
        role == .host
    }

    var isStripeReady: Bool {
        let statusReady = stripeStatus == "ready"
        return (stripeAccountId?.isEmpty == false) && ((stripeOnboarded == true) || statusReady)
    }

    var stripeStatusDisplay: String {
        switch stripeStatus {
        case "ready":
            return "Ready"
        case "pending":
            return "Pending"
        case "not_ready":
            return "Not ready"
        default:
            return isStripeReady ? "Ready" : "Not ready"
        }
    }
}
