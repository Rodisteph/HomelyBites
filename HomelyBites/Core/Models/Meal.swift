
import Foundation
import FirebaseFirestore

struct Meal: Identifiable {

    var id: String
    var title: String
    var description: String
    var priceCents: Int
    var availablePortions: Int
    var hostId: String
    var hostName: String
    var tags: [String]
    var createdAt: Timestamp?

}
extension Meal {

    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }

        self.id = document.documentID
        self.title = data["title"] as? String ?? ""
        self.description = data["description"] as? String ?? ""
        self.priceCents = data["priceCents"] as? Int ?? 0
        self.availablePortions = data["availablePortions"] as? Int ?? 0
        self.hostId = data["hostId"] as? String ?? ""
        self.hostName = data["hostName"] as? String ?? ""
        self.tags = data["tags"] as? [String] ?? []
        self.createdAt = data["createdAt"] as? Timestamp
    }

    func toFirestore() -> [String: Any] {
        [
            "title": title,
            "description": description,
            "priceCents": priceCents,
            "availablePortions": availablePortions,
            "hostId": hostId,
            "hostName": hostName,
            "tags": tags,
            "createdAt": FieldValue.serverTimestamp()
        ]
    }
}
