import Foundation
import FirebaseFirestore

extension AppUser {

    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }

        guard let fullName = data["fullName"] as? String,
              let roleRaw = data["role"] as? String,
              let role = UserRole(rawValue: roleRaw)
        else {
            return nil
        }

        self.id = document.documentID
        self.fullName = fullName
        self.role = role
        self.stripeAccountId = data["stripeAccountId"] as? String
        self.stripeOnboarded = data["stripeOnboarded"] as? Bool
    }

    func toFirestore() -> [String: Any] {
        var dict: [String: Any] = [
            "fullName": fullName,
            "role": role.rawValue
        ]

        if let stripeAccountId {
            dict["stripeAccountId"] = stripeAccountId
        }

        if let stripeOnboarded {
            dict["stripeOnboarded"] = stripeOnboarded
        }

        return dict
    }
}
