import Foundation
import FirebaseFirestore

struct Order: Identifiable {
    var id: String
    var mealId: String
    var clientId: String
    var hostId: String
    var hostStripeAccountId: String
    var portions: Int
    var note: String
    var status: OrderStatus
    var paymentStatus: PaymentStatus
    var amountCents: Int
    var currency: String
    var paymentIntentId: String?
    var createdAt: Timestamp?
}

extension Order {

    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }

        self.id                  = document.documentID
        self.mealId              = data["mealId"] as? String ?? ""
        self.clientId            = data["clientId"] as? String ?? ""
        self.hostId              = data["hostId"] as? String ?? ""
        self.hostStripeAccountId = data["hostStripeAccountId"] as? String ?? ""
        self.portions            = data["portions"] as? Int ?? 0
        self.note                = data["note"] as? String ?? ""
        self.status              = OrderStatus(rawValue: data["status"] as? String ?? "") ?? .pending
        self.paymentStatus       = PaymentStatus(rawValue: data["paymentStatus"] as? String ?? "") ?? .requires_payment
        self.amountCents         = data["amountCents"] as? Int ?? 0
        self.currency            = data["currency"] as? String ?? "eur"
        self.paymentIntentId     = data["paymentIntentId"] as? String
        self.createdAt           = data["createdAt"] as? Timestamp
    }

    func toFirestore() -> [String: Any] {
        [
            "mealId":              mealId,
            "clientId":            clientId,
            "hostId":              hostId,
            "hostStripeAccountId": hostStripeAccountId,
            "portions":            portions,
            "note":                note,
            "status":              status.rawValue,
            "paymentStatus":       paymentStatus.rawValue,
            "amountCents":         amountCents,
            "currency":            currency,
            "paymentIntentId":     paymentIntentId as Any,
            "createdAt":           FieldValue.serverTimestamp()
        ]
    }
}
