
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

    func fetchMeals(hostId: String) async throws -> [Meal] {
        let snapshot = try await db
            .collection("meals")
            .whereField("hostId", isEqualTo: hostId)
            .getDocumentsAsync()

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

    func deleteMeal(mealId: String, hostId: String) async throws {
        let mealRef = db.collection("meals").document(mealId)
        let snapshot = try await mealRef.getDocumentAsync()

        guard snapshot.exists else {
            #if DEBUG
            debugLog("[FirestoreService][deleteMeal] meal already deleted mealId=\(mealId)")
            #endif
            return
        }

        guard let data = snapshot.data(),
              let ownerId = data["hostId"] as? String else {
            throw AppError.invalidResponse
        }

        guard ownerId == hostId else {
            throw AppError.invalidInput("Suppression refusee: ce plat n'appartient pas a ce compte host.")
        }

        try await mealRef.deleteAsync()
        #if DEBUG
        debugLog("[FirestoreService][deleteMeal] success mealId=\(mealId) hostId=\(hostId)")
        #endif
    }

    // MARK: - Orders

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

    private func debugLog(_ message: String) {
        #if DEBUG
        NSLog("%@", message)
        #endif
    }
}
