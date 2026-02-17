
import Foundation
import FirebaseFirestore

final class FirestoreService {
    private lazy var db = Firestore.firestore()

    // MARK: - Users

    func fetchUser(uid: String) async throws -> AppUser {
        let snapshot = try await db.collection("users").document(uid).getDocumentAsync()
        guard snapshot.exists, let user = AppUser(document: snapshot) else {
            throw AppError.missingUserProfile
        }
        return user
    }

    // MARK: - Meals

    func fetchMeals() async throws -> [Meal] {
        let snapshot = try await db.collection("meals").getDocumentsAsync()
        let meals = snapshot.documents.compactMap { Meal(document: $0) }

        return meals.sorted {
            ($0.createdAt?.dateValue() ?? .distantPast) > ($1.createdAt?.dateValue() ?? .distantPast)
        }
    }

    func createMeal(
        host: AppUser,
        title: String,
        description: String,
        priceCents: Int,
        availablePortions: Int,
        tags: [String]
    ) async throws {
        let docRef = db.collection("meals").document()

        let meal = Meal(
            id: docRef.documentID,
            title: title,
            description: description,
            priceCents: priceCents,
            availablePortions: availablePortions,
            hostId: host.id,
            hostName: host.fullName,
            tags: tags,
            createdAt: nil
        )

        try await docRef.setDataAsync(meal.toFirestore(), merge: true)
    }

    func createDemoMeals(host: AppUser) async throws {
        try await createMeal(
            host: host,
            title: "Lasagna Maison",
            description: "Lasagne boeuf, bechamel, portion genereuse.",
            priceCents: 1200,
            availablePortions: 6,
            tags: ["italian", "family"]
        )

        try await createMeal(
            host: host,
            title: "Couscous Veggie",
            description: "Semoule fine, legumes frais et pois chiches.",
            priceCents: 980,
            availablePortions: 8,
            tags: ["veggie", "healthy"]
        )
    }

    // MARK: - Orders

    func createOrder(
        meal: Meal,
        clientId: String,
        hostStripeAccountId: String,
        portions: Int,
        note: String
    ) async throws -> String {

        let amountCents = meal.priceCents * portions
        let orderRef = db.collection("orders").document()

        let order = Order(
            id: orderRef.documentID,
            mealId: meal.id,
            clientId: clientId,
            hostId: meal.hostId,
            hostStripeAccountId: hostStripeAccountId,
            portions: portions,
            note: note,
            status: .pending,
            paymentStatus: .requires_payment,
            amountCents: amountCents,
            currency: "eur",
            paymentIntentId: nil,
            createdAt: nil
        )

        try await orderRef.setDataAsync(order.toFirestore(), merge: true)
        return orderRef.documentID
    }

    func fetchClientOrders(clientId: String) async throws -> [Order] {
        let snapshot = try await db
            .collection("orders")
            .whereField("clientId", isEqualTo: clientId)
            .getDocumentsAsync()

        let orders = snapshot.documents.compactMap { Order(document: $0) }

        return orders.sorted {
            ($0.createdAt?.dateValue() ?? .distantPast) > ($1.createdAt?.dateValue() ?? .distantPast)
        }
    }

    func fetchHostOrders(hostId: String) async throws -> [Order] {
        let snapshot = try await db
            .collection("orders")
            .whereField("hostId", isEqualTo: hostId)
            .getDocumentsAsync()

        let orders = snapshot.documents.compactMap { Order(document: $0) }

        return orders.sorted {
            ($0.createdAt?.dateValue() ?? .distantPast) > ($1.createdAt?.dateValue() ?? .distantPast)
        }
    }

    func listenClientOrders(
        clientId: String,
        onUpdate: @escaping (Result<[Order], Error>) -> Void
    ) -> ListenerRegistration {
        db.collection("orders")
            .whereField("clientId", isEqualTo: clientId)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onUpdate(.failure(error))
                    return
                }
                guard let snapshot else {
                    onUpdate(.failure(AppError.invalidResponse))
                    return
                }

                let orders = snapshot.documents
                    .compactMap { Order(document: $0) }
                    .sorted {
                        ($0.createdAt?.dateValue() ?? .distantPast) > ($1.createdAt?.dateValue() ?? .distantPast)
                    }

                onUpdate(.success(orders))
            }
    }

    func listenHostOrders(
        hostId: String,
        onUpdate: @escaping (Result<[Order], Error>) -> Void
    ) -> ListenerRegistration {
        db.collection("orders")
            .whereField("hostId", isEqualTo: hostId)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onUpdate(.failure(error))
                    return
                }
                guard let snapshot else {
                    onUpdate(.failure(AppError.invalidResponse))
                    return
                }

                let orders = snapshot.documents
                    .compactMap { Order(document: $0) }
                    .sorted {
                        ($0.createdAt?.dateValue() ?? .distantPast) > ($1.createdAt?.dateValue() ?? .distantPast)
                    }

                onUpdate(.success(orders))
            }
    }

    func updateOrderStatus(orderId: String, status: OrderStatus) async throws {
        try await db.collection("orders")
            .document(orderId)
            .updateDataAsync(["status": status.rawValue])
    }
}
