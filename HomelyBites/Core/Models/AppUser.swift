import Foundation
import FirebaseFirestore

struct AppUser: Codable, Identifiable {
    var id: String
    var fullName: String
    var role: UserRole

    var isHost: Bool { role == .host }
}

extension AppUser {

    init?(document: DocumentSnapshot) {
        guard
            let data = document.data(),
            let fullName = data["fullName"] as? String,
            let roleRaw = data["role"] as? String,
            let role = UserRole(rawValue: roleRaw)
        else { return nil }

        self.id = document.documentID
        self.fullName = fullName
        self.role = role
    }

    func toFirestore() -> [String: Any] {
        [
            "fullName": fullName,
            "role": role.rawValue
        ]
    }
}
