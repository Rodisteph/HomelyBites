import Foundation
import FirebaseAuth
import FirebaseFirestore

// 🔐 Gère la connexion / inscription / déconnexion.
// Simplifié : on utilise directement try await (Firebase SDK 10+)
// — plus besoin des wrappers de Firestore+Async.swift.
final class AuthService {

    private let auth = Auth.auth()
    private let db   = Firestore.firestore()

    func signIn(email: String, password: String) async throws {
        try await auth.signIn(withEmail: email, password: password)
    }

    func signUp(
        email: String,
        password: String,
        fullName: String,
        role: UserRole
    ) async throws {
        let result = try await auth.createUser(withEmail: email, password: password)

        let user = AppUser(
            id: result.user.uid,
            fullName: fullName,
            role: role,
            stripeAccountId: nil,
            stripeOnboarded: false
        )
        try await db.collection("users").document(result.user.uid).setData(user.toFirestore())
    }

    func signOut() throws {
        try auth.signOut()
    }
}
