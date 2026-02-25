import Foundation
import FirebaseFirestore

struct Order: Identifiable, Codable {
    @DocumentID var id: String?
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
    @ServerTimestamp var createdAt: Timestamp?
}
