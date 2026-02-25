import Foundation
import FirebaseFirestore

final class FirestoreService {
    private lazy var db = Firestore.firestore()

    // MARK: - Users

    func fetchUser(uid: String) async throws -> AppUser {
        var user = try await db.collection("users").document(uid).getDocument(as: AppUser.self)
        if user.id.isEmpty { user.id = uid }
        return user
    }

    func updateUserProfile(
        uid: String,
        fullName: String,
        bio: String?,
        chefLevel: String?,
        photoURL: String?
    ) async throws {
        let cleanedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        var payload: [String: Any] = [
            "fullName": cleanedName,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        let cleanedBio = bio?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        payload["bio"] = cleanedBio.isEmpty ? FieldValue.delete() : cleanedBio

        let cleanedChefLevel = chefLevel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        payload["chefLevel"] = cleanedChefLevel.isEmpty ? FieldValue.delete() : cleanedChefLevel

        let cleanedPhotoURL = photoURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        payload["photoURL"] = cleanedPhotoURL.isEmpty ? FieldValue.delete() : cleanedPhotoURL

        #if DEBUG
        debugLog("[FirestoreService][updateUserProfile] start users/\(uid)")
        #endif

        do {
            try await db.collection("users").document(uid).setDataAsync(payload, merge: true)
            #if DEBUG
            debugLog("[FirestoreService][updateUserProfile] success users/\(uid)")
            #endif
        } catch {
            #if DEBUG
            logNSErrorDetails(error, context: "updateUserProfile", path: "users/\(uid)")
            #endif
            throw error
        }
    }

    // MARK: - Meals

    func fetchMeals() async throws -> [Meal] {
        let snapshot = try await db.collection("meals").getDocumentsAsync()
        let meals = try snapshot.documents.map { try decodeMealDocument($0) }
        return meals.sorted {
            ($0.createdAt?.dateValue() ?? .distantPast) > ($1.createdAt?.dateValue() ?? .distantPast)
        }
    }

    func fetchMeals(hostId: String) async throws -> [Meal] {
        let snapshot = try await db
            .collection("meals")
            .whereField("hostId", isEqualTo: hostId)
            .getDocumentsAsync()

        let meals = try snapshot.documents.map { try decodeMealDocument($0) }

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
        serviceMode: MealServiceMode
    ) async throws -> String {
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
            serviceMode: serviceMode,
            location: GeoPoint(latitude: 52.3676, longitude: 4.9041),
            locationName: "Amsterdam",
            city: "Amsterdam",
            createdAt: nil
        )

        try await docRef.setData(from: meal)
        return docRef.documentID
    }

    func setMealPhoto(mealId: String, imageURL: String, imagePath: String) async throws {
        let trimmedURL = imageURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPath = imagePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty, !trimmedPath.isEmpty else {
            throw AppError.invalidInput("Photo repas invalide.")
        }

        #if DEBUG
        debugLog("[FirestoreService][setMealPhoto] start mealId=\(mealId)")
        #endif

        do {
            try await db.collection("meals").document(mealId).setDataAsync([
                "imageURL": trimmedURL,
                "imagePath": trimmedPath,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            #if DEBUG
            debugLog("[FirestoreService][setMealPhoto] success mealId=\(mealId)")
            #endif
        } catch {
            #if DEBUG
            logNSErrorDetails(error, context: "setMealPhoto", path: "meals/\(mealId)")
            #endif
            throw error
        }
    }

    func createDemoMeals(host: AppUser) async throws {
        _ = try await createMeal(
            host: host,
            title: "Lasagna Maison",
            description: "Lasagne boeuf, bechamel, portion genereuse.",
            priceCents: 1200,
            availablePortions: 6,
            tags: ["italian", "family"],
            serviceMode: .onSite
        )

        _ = try await createMeal(
            host: host,
            title: "Couscous Veggie",
            description: "Semoule fine, legumes frais et pois chiches.",
            priceCents: 980,
            availablePortions: 8,
            tags: ["veggie", "healthy"],
            serviceMode: .onSite
        )
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

        var meal = try snapshot.data(as: Meal.self)
        if meal.id.isEmpty {
            meal.id = snapshot.documentID
        }
        guard !meal.hostId.isEmpty else {
            throw AppError.invalidInput("Suppression impossible: proprietaire du plat introuvable.")
        }

        guard meal.hostId == hostId else {
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
        let orders = try await db
            .collection("orders")
            .whereField("clientId", isEqualTo: clientId)
            .getDocuments(as: Order.self)

        return orders.sorted {
            ($0.createdAt?.dateValue() ?? .distantPast) > ($1.createdAt?.dateValue() ?? .distantPast)
        }
    }

    func fetchHostOrders(hostId: String) async throws -> [Order] {
        let orders = try await db
            .collection("orders")
            .whereField("hostId", isEqualTo: hostId)
            .getDocuments(as: Order.self)

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

                do {
                    let orders = try snapshot.documents
                        .map { try $0.data(as: Order.self) }
                        .sorted {
                            ($0.createdAt?.dateValue() ?? .distantPast) > ($1.createdAt?.dateValue() ?? .distantPast)
                        }
                    onUpdate(.success(orders))
                } catch {
                    onUpdate(.failure(error))
                }
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

                do {
                    let orders = try snapshot.documents
                        .map { try $0.data(as: Order.self) }
                        .sorted {
                            ($0.createdAt?.dateValue() ?? .distantPast) > ($1.createdAt?.dateValue() ?? .distantPast)
                        }
                    onUpdate(.success(orders))
                } catch {
                    onUpdate(.failure(error))
                }
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

    private func decodeMealDocument(_ document: QueryDocumentSnapshot) throws -> Meal {
        var meal = try document.data(as: Meal.self)
        // Always trust Firestore documentID for destructive operations (delete/update).
        meal.id = document.documentID
        return meal
    }
}
