import Foundation
import FirebaseFirestore

enum MealServiceMode: String, Codable, CaseIterable, Identifiable {
    case onSite = "on_site"
    case takeaway = "takeaway"
    case both = "both"

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .onSite:
            return "Sur place"
        case .takeaway:
            return "A emporter"
        case .both:
            return "Sur place / A emporter"
        }
    }
}

struct Meal: Identifiable, Codable {
    var id: String
    var title: String
    var description: String
    var priceCents: Int
    var availablePortions: Int
    var hostId: String
    var hostName: String
    var tags: [String]
    var serviceMode: MealServiceMode?
    var location: GeoPoint?
    var locationName: String?
    var city: String?
    var imageURL: String?
    var imagePath: String?
    @ServerTimestamp var createdAt: Timestamp?

    init(
        id: String,
        title: String,
        description: String,
        priceCents: Int,
        availablePortions: Int,
        hostId: String,
        hostName: String,
        tags: [String],
        serviceMode: MealServiceMode? = nil,
        location: GeoPoint? = nil,
        locationName: String? = nil,
        city: String? = nil,
        imageURL: String? = nil,
        imagePath: String? = nil,
        createdAt: Timestamp? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.priceCents = priceCents
        self.availablePortions = availablePortions
        self.hostId = hostId
        self.hostName = hostName
        self.tags = tags
        self.serviceMode = serviceMode
        self.location = location
        self.locationName = locationName
        self.city = city
        self.imageURL = imageURL
        self.imagePath = imagePath
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        priceCents = try container.decodeIfPresent(Int.self, forKey: .priceCents) ?? 0
        availablePortions = try container.decodeIfPresent(Int.self, forKey: .availablePortions) ?? 0
        hostId = try container.decodeIfPresent(String.self, forKey: .hostId) ?? ""
        hostName = try container.decodeIfPresent(String.self, forKey: .hostName) ?? ""
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        serviceMode = try container.decodeIfPresent(MealServiceMode.self, forKey: .serviceMode)
        location = try container.decodeIfPresent(GeoPoint.self, forKey: .location)
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
            ?? legacyContainer.decodeIfPresent(String.self, forKey: .imageUrl)
            ?? legacyContainer.decodeIfPresent(String.self, forKey: .photoURL)
        imagePath = try container.decodeIfPresent(String.self, forKey: .imagePath)
            ?? legacyContainer.decodeIfPresent(String.self, forKey: .photoPath)
        createdAt = try container.decodeIfPresent(Timestamp.self, forKey: .createdAt)
    }

    var availableServiceModes: [MealServiceMode] {
        switch serviceMode ?? .onSite {
        case .onSite:
            return [.onSite]
        case .takeaway:
            return [.takeaway]
        case .both:
            return [.onSite, .takeaway]
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case priceCents
        case availablePortions
        case hostId
        case hostName
        case tags
        case serviceMode
        case location
        case locationName
        case city
        case imageURL
        case imagePath
        case createdAt
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case imageUrl
        case photoURL
        case photoPath
    }
}
