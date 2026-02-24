
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
        let snapshot = try await db
            .collection("meals")
            .whereField("isPublic", isEqualTo: true)
            .getDocumentsAsync()
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
        tags: [String],
        isPublic: Bool = false
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
            isPublic: isPublic,
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
            tags: ["italian", "family"],
            isPublic: true
        )

        try await createMeal(
            host: host,
            title: "Couscous Veggie",
            description: "Semoule fine, legumes frais et pois chiches.",
            priceCents: 980,
            availablePortions: 8,
            tags: ["veggie", "healthy"],
            isPublic: true
        )
    }

    func updateMealVisibility(mealId: String, isPublic: Bool) async throws {
        try await db.collection("meals").document(mealId).updateDataAsync(["isPublic": isPublic])
    }

    func deleteMeal(mealId: String, hostId: String) async throws {
        #if DEBUG
        debugLog("[FirestoreService][deleteMeal] start path=meals/\(mealId) hostId=\(hostId)")
        #endif
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

        do {
            try await mealRef.deleteAsync()
            #if DEBUG
            debugLog("[FirestoreService][deleteMeal] success path=meals/\(mealId)")
            #endif
        } catch {
            #if DEBUG
            logNSErrorDetails(error, context: "deleteMeal", path: "meals/\(mealId)")
            #endif
            throw error
        }
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

    private func logNSErrorDetails(_ error: Error, context: String, path: String) {
        #if DEBUG
        let nsError = error as NSError
        debugLog("[FirestoreService][\(context)] failed path=\(path)")
        debugLog("[FirestoreService][\(context)] domain=\(nsError.domain) code=\(nsError.code)")
        debugLog("[FirestoreService][\(context)] localizedDescription=\(nsError.localizedDescription)")
        debugLog("[FirestoreService][\(context)] userInfo=\(nsError.userInfo)")
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            debugLog("[FirestoreService][\(context)] underlying.domain=\(underlying.domain) code=\(underlying.code)")
            debugLog("[FirestoreService][\(context)] underlying.localizedDescription=\(underlying.localizedDescription)")
            debugLog("[FirestoreService][\(context)] underlying.userInfo=\(underlying.userInfo)")
        }
        #endif
    }
}
