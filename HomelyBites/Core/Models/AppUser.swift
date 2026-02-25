
import Foundation

struct AppUser: Codable, Identifiable {
    var id: String
    var fullName: String
    var role: UserRole
    var photoURL: String?
    var bio: String?
    var chefLevel: String?
    var haccpAcceptedAt: Date?
    var haccpVersion: String?
    var stripeAccountId: String?
    var stripeOnboarded: Bool?
    var stripeStatus: String?

    init(
        id: String,
        fullName: String,
        role: UserRole,
        photoURL: String? = nil,
        bio: String? = nil,
        chefLevel: ChefLevel? = nil,
        haccpAcceptedAt: Date? = nil,
        haccpVersion: String? = nil,
        stripeAccountId: String? = nil,
        stripeOnboarded: Bool? = nil,
        stripeStatus: String? = nil
    ) {
        self.id = id
        self.fullName = fullName
        self.role = role
        self.photoURL = photoURL
        self.bio = bio
        self.chefLevel = chefLevel?.rawValue
        self.haccpAcceptedAt = haccpAcceptedAt
        self.haccpVersion = haccpVersion
        self.stripeAccountId = stripeAccountId
        self.stripeOnboarded = stripeOnboarded
        self.stripeStatus = stripeStatus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        fullName = try container.decodeIfPresent(String.self, forKey: .fullName)
            ?? container.decodeIfPresent(String.self, forKey: .displayName)
            ?? ""
        role = try container.decode(UserRole.self, forKey: .role)
        photoURL = try container.decodeIfPresent(String.self, forKey: .photoURL)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        chefLevel = try container.decodeIfPresent(String.self, forKey: .chefLevel)
        haccpAcceptedAt = try container.decodeIfPresent(Date.self, forKey: .haccpAcceptedAt)
        haccpVersion = try container.decodeIfPresent(String.self, forKey: .haccpVersion)
        stripeAccountId = try container.decodeIfPresent(String.self, forKey: .stripeAccountId)
        stripeOnboarded = try container.decodeIfPresent(Bool.self, forKey: .stripeOnboarded)
        stripeStatus = try container.decodeIfPresent(String.self, forKey: .stripeStatus)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fullName, forKey: .fullName)
        try container.encode(role, forKey: .role)
        try container.encodeIfPresent(photoURL, forKey: .photoURL)
        try container.encodeIfPresent(bio, forKey: .bio)
        try container.encodeIfPresent(chefLevel, forKey: .chefLevel)
        try container.encodeIfPresent(haccpAcceptedAt, forKey: .haccpAcceptedAt)
        try container.encodeIfPresent(haccpVersion, forKey: .haccpVersion)
        try container.encodeIfPresent(stripeAccountId, forKey: .stripeAccountId)
        try container.encodeIfPresent(stripeOnboarded, forKey: .stripeOnboarded)
        try container.encodeIfPresent(stripeStatus, forKey: .stripeStatus)
    }

    var displayName: String {
        get { fullName }
        set { fullName = newValue }
    }

    var chefLevelEnum: ChefLevel? {
        guard let chefLevel else { return nil }
        return ChefLevel(rawValue: chefLevel)
    }

    var isHost: Bool {
        role == .host
    }

    var hasAcceptedHaccp: Bool {
        haccpAcceptedAt != nil
            && !(haccpVersion?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    var isStripeReady: Bool {
        let statusReady = stripeStatus == "ready" || stripeStatus == "enabled"
        return (stripeAccountId?.isEmpty == false) && ((stripeOnboarded == true) || statusReady)
    }

    var stripeStatusDisplay: String {
        switch stripeStatus {
        case "ready":
            return "Ready"
        case "enabled":
            return "Ready"
        case "pending":
            return "Pending"
        case "not_ready":
            return "Not ready"
        default:
            return isStripeReady ? "Ready" : "Not ready"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case fullName
        case displayName
        case role
        case photoURL
        case bio
        case chefLevel
        case haccpAcceptedAt
        case haccpVersion
        case stripeAccountId
        case stripeOnboarded
        case stripeStatus
    }
}
