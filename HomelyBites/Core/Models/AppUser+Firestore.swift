import Foundation
import FirebaseFirestore

extension AppUser {

    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }

        guard let displayName = (data["displayName"] as? String) ?? (data["fullName"] as? String),
              let roleRaw = data["role"] as? String,
              let role = UserRole(rawValue: roleRaw)
        else {
            return nil
        }

        self.id = document.documentID
        self.displayName = displayName
        self.role = role
        self.photoURL = data["photoURL"] as? String
        self.bio = data["bio"] as? String ?? ""
        self.chefLevel = ChefLevel(rawValue: (data["chefLevel"] as? String) ?? "") ?? .beginner
        self.stripeAccountId = data["stripeAccountId"] as? String
        self.stripeOnboarded = data["stripeOnboarded"] as? Bool
        self.stripeStatus = data["stripeStatus"] as? String
    }

    func toFirestore() -> [String: Any] {
        var dict: [String: Any] = [
            "displayName": displayName,
            "fullName": displayName,
            "role": role.rawValue,
            "bio": bio,
            "chefLevel": chefLevel.rawValue
        ]

        if let photoURL, !photoURL.isEmpty {
            dict["photoURL"] = photoURL
        }

        if let stripeAccountId {
            dict["stripeAccountId"] = stripeAccountId
        }

        if let stripeOnboarded {
            dict["stripeOnboarded"] = stripeOnboarded
        }

        if let stripeStatus {
            dict["stripeStatus"] = stripeStatus
        }

        return dict
    }
}
