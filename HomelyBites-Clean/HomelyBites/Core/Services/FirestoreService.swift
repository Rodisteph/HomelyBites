import Foundation
import FirebaseFirestore

// 🗄️ Toutes les opérations Firestore.
// Simplifié : try await natif (Firebase SDK 10+) —
// plus besoin des wrappers getDocumentAsync / getDocumentsAsync / setDataAsync.
final class FirestoreService {

    private let db = Firestore.firestore()

    // MARK: - Users

    func fetchUser(uid: String) async throws -> AppUser {
        let snapshot = try await db.collection("users").document(uid).getDocument()
        guard snapshot.exists, let user = AppUser(document: snapshot) else {
            throw AppError.missingUserProfile
        }
        return user
    }

    // MARK: - Meals

    func fetchMeals() async throws -> [Meal] {
        let snapshot = try await db.collection("meals").getDocuments()
        return snapshot.documents
            .compactMap { Meal(document: $0) }
            .sorted { ($0.createdAt?.dateValue() ?? .distantPast) > ($1.createdAt?.dateValue() ?? .distantPast) }
    }

    func createMeal(
        host: AppUser,
        title: String,
        description: String,
        priceCents: Int,
        availablePortions: Int,
        tags: [String]
    ) async throws {
        let ref  = db.collection("meals").document()
        let meal = Meal(
            id: ref.documentID, title: title, description: description,
            priceCents: priceCents, availablePortions: availablePortions,
            hostId: host.id, hostName: host.fullName, tags: tags, createdAt: nil
        )
        try await ref.setData(meal.toFirestore())
    }

    func createDemoMeals(host: AppUser) async throws {
        try await createMeal(host: host, title: "Lasagna Maison",
            description: "Lasagne boeuf, bechamel, portion genereuse.",
            priceCents: 1200, availablePortions: 6, tags: ["italian", "family"])
        try await createMeal(host: host, title: "Couscous Veggie",
            description: "Semoule fine, legumes frais et pois chiches.",
            priceCents: 980, availablePortions: 8, tags: ["veggie", "healthy"])
    }

    // MARK: - Orders

    func createOrder(
        meal: Meal,
        clientId: String,
        hostStripeAccountId: String,
        portions: Int,
        note: String
    ) async throws -> String {
        let ref   = db.collection("orders").document()
        let order = Order(
            id: ref.documentID, mealId: meal.id, clientId: clientId,
            hostId: meal.hostId, hostStripeAccountId: hostStripeAccountId,
            portions: portions, note: note, status: .pending,
            paymentStatus: .requires_payment,
            amountCents: meal.priceCents * portions, currency: "eur",
            paymentIntentId: nil, createdAt: nil
        )
        try await ref.setData(order.toFirestore())
        return ref.documentID
    }

    func fetchClientOrders(clientId: String) async throws -> [Order] {
        let snapshot = try await db.collection("orders")
            .whereField("clientId", isEqualTo: clientId)
            .getDocuments()
        return sortedOrders(snapshot.documents)
    }

    func fetchHostOrders(hostId: String) async throws -> [Order] {
        let snapshot = try await db.collection("orders")
            .whereField("hostId", isEqualTo: hostId)
            .getDocuments()
        return sortedOrders(snapshot.documents)
    }

    func listenClientOrders(
        clientId: String,
        onUpdate: @escaping (Result<[Order], Error>) -> Void
    ) -> ListenerRegistration {
        db.collection("orders")
            .whereField("clientId", isEqualTo: clientId)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.handleOrderSnapshot(snapshot, error, onUpdate)
            }
    }

    func listenHostOrders(
        hostId: String,
        onUpdate: @escaping (Result<[Order], Error>) -> Void
    ) -> ListenerRegistration {
        db.collection("orders")
            .whereField("hostId", isEqualTo: hostId)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.handleOrderSnapshot(snapshot, error, onUpdate)
            }
    }

    func updateOrderStatus(orderId: String, status: OrderStatus) async throws {
        try await db.collection("orders").document(orderId)
            .updateData(["status": status.rawValue])
    }

    // MARK: - Helpers privés

    private func sortedOrders(_ documents: [QueryDocumentSnapshot]) -> [Order] {
        documents
            .compactMap { Order(document: $0) }
            .sorted { ($0.createdAt?.dateValue() ?? .distantPast) > ($1.createdAt?.dateValue() ?? .distantPast) }
    }

    private func handleOrderSnapshot(
        _ snapshot: QuerySnapshot?,
        _ error: Error?,
        _ onUpdate: (Result<[Order], Error>) -> Void
    ) {
        if let error  { onUpdate(.failure(error)); return }
        guard let snapshot else { onUpdate(.failure(AppError.invalidResponse)); return }
        onUpdate(.success(sortedOrders(snapshot.documents)))
    }
}
