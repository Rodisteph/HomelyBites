import Foundation
import FirebaseAuth
import FirebaseFirestore

final class AuthService {
    private lazy var auth = Auth.auth()
    private lazy var db = Firestore.firestore()
    private let usersCollection = "users"

    func signIn(email: String, password: String) async throws {
        _ = try await auth.signInAsync(email: email, password: password)
    }

    func signUp(email: String, password: String, fullName: String, role: UserRole) async throws {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        #if DEBUG
        debugLog("[AuthService][signUp] start email=\(maskedEmail(normalizedEmail)) role=\(role.rawValue)")
        #endif

        let result: AuthDataResult
        do {
            result = try await auth.createUserAsync(email: normalizedEmail, password: password)
            #if DEBUG
            debugLog("[AuthService][signUp] auth.createUser success uid=\(result.user.uid) email=\(maskedEmail(normalizedEmail)) role=\(role.rawValue)")
            #endif
        } catch {
            logNSErrorDetails(
                error,
                context: "auth.createUser",
                email: normalizedEmail,
                role: role,
                userId: nil
            )
            throw error
        }

        let user = AppUser(
            id: result.user.uid,
            fullName: fullName,
            role: role,
            stripeAccountId: nil,
            stripeOnboarded: false
        )

        #if DEBUG
        debugLog("[AuthService][signUp] firestore.write start collection=\(usersCollection) uid=\(result.user.uid)")
        #endif
        do {
            try await db.collection(usersCollection).document(result.user.uid).setData(user.toFirestore())
            #if DEBUG
            debugLog("[AuthService][signUp] firestore.write success uid=\(result.user.uid)")
            #endif
        } catch {
            logNSErrorDetails(
                error,
                context: "firestore.users.write",
                email: normalizedEmail,
                role: role,
                userId: result.user.uid
            )
            throw error
        }
    }

    func signOut() throws {
        try auth.signOut()
    }

    private func maskedEmail(_ email: String) -> String {
        let parts = email.split(separator: "@", maxSplits: 1).map(String.init)
        guard parts.count == 2 else {
            return "***"
        }

        let local = parts[0]
        let domain = parts[1]
        let visibleLocal = local.prefix(2)
        return "\(visibleLocal)***@\(domain)"
    }

    private func logNSErrorDetails(
        _ error: Error,
        context: String,
        email: String,
        role: UserRole,
        userId: String?
    ) {
        #if DEBUG
        let nsError = error as NSError
        debugLog("[AuthService][\(context)] signup_failed email=\(maskedEmail(email)) role=\(role.rawValue) uid=\(userId ?? "nil")")
        debugLog("[AuthService][\(context)] domain=\(nsError.domain) code=\(nsError.code)")
        debugLog("[AuthService][\(context)] localizedDescription=\(nsError.localizedDescription)")
        debugLog("[AuthService][\(context)] userInfo=\(nsError.userInfo)")

        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            debugLog("[AuthService][\(context)] underlying[0].domain=\(underlying.domain) code=\(underlying.code)")
            debugLog("[AuthService][\(context)] underlying[0].localizedDescription=\(underlying.localizedDescription)")
            debugLog("[AuthService][\(context)] underlying[0].userInfo=\(underlying.userInfo)")
        }

        if let detailedErrors = nsError.userInfo["NSDetailedErrors"] as? [NSError], !detailedErrors.isEmpty {
            for (index, item) in detailedErrors.enumerated() {
                debugLog("[AuthService][\(context)] detailed[\(index)].domain=\(item.domain) code=\(item.code)")
                debugLog("[AuthService][\(context)] detailed[\(index)].localizedDescription=\(item.localizedDescription)")
                debugLog("[AuthService][\(context)] detailed[\(index)].userInfo=\(item.userInfo)")
            }
        }
        #endif
    }

    #if DEBUG
    func debugSignUpProbe(email: String, password: String, fullName: String, role: UserRole) async {
        do {
            try await signUp(email: email, password: password, fullName: fullName, role: role)
            debugLog("[AuthService][debugProbe] success email=\(maskedEmail(email)) role=\(role.rawValue)")
        } catch {
            logNSErrorDetails(
                error,
                context: "debugProbe",
                email: email,
                role: role,
                userId: nil
            )
        }
    }
    #endif

    private func debugLog(_ message: String) {
        #if DEBUG
        NSLog("%@", message)
        #endif
    }
}
