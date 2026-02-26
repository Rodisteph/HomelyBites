import Foundation
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import UIKit

final class AuthService {
    private lazy var auth = Auth.auth()
    private lazy var db = Firestore.firestore()
    private let usersCollection = "users"

    func signIn(email: String, password: String) async throws {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        #if DEBUG
        debugLog("[AuthService][signIn] start email=\(maskedEmail(normalizedEmail))")
        #endif

        do {
            _ = try await auth.signInAsync(email: normalizedEmail, password: password)
            #if DEBUG
            debugLog("[AuthService][signIn] success email=\(maskedEmail(normalizedEmail)) uid=\(auth.currentUser?.uid ?? "nil")")
            #endif
        } catch {
            logNSErrorDetails(
                error,
                context: "auth.signIn",
                email: normalizedEmail,
                role: nil,
                userId: auth.currentUser?.uid
            )
            throw error
        }
    }

    func signInWithGoogle(presenting: UIViewController) async throws -> AuthDataResult {
        #if DEBUG
        debugLog("[GOOGLE] start")
        #endif

        guard let clientID = FirebaseRuntimeConfig.googleClientID() else {
            #if DEBUG
            debugLog("[GOOGLE] clientID missing. \(FirebaseRuntimeConfig.googleChecklist())")
            #endif
            throw AppError.invalidInput("Google Sign-In non configure (clientID Firebase manquant). Verifie GoogleService-Info.plist + URL scheme.")
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        do {
            let signInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
            guard let idToken = signInResult.user.idToken?.tokenString else {
                throw AppError.invalidInput("Google Sign-In non configure (idToken Google manquant).")
            }

            let accessToken = signInResult.user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: accessToken
            )

            let authResult = try await signInWithCredentialAsync(credential)
            #if DEBUG
            debugLog("[GOOGLE] success uid=\(authResult.user.uid)")
            #endif
            return authResult
        } catch {
            logNSErrorDetails(
                error,
                context: "google.signIn",
                email: auth.currentUser?.email ?? "google-user",
                role: nil,
                userId: auth.currentUser?.uid
            )
            throw error
        }
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
            let userRef = db.collection(usersCollection).document(result.user.uid)
            try await userRef.setData(from: user)
            let snapshot = try await userRef.getDocumentAsync()
            let savedUser = try snapshot.data(as: AppUser.self)
            _ = savedUser
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

    func sendPasswordReset(email: String) async throws {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedEmail.isEmpty else {
            throw AppError.invalidInput("Email requis pour reinitialiser le mot de passe.")
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            auth.sendPasswordReset(withEmail: normalizedEmail) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func fetchUserProfile(uid: String) async throws -> AppUser {
        let snapshot = try await db.collection(usersCollection).document(uid).getDocumentAsync()
        var user = try snapshot.data(as: AppUser.self)
        if user.id.isEmpty {
            user.id = snapshot.documentID
        }
        return user
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
        role: UserRole?,
        userId: String?
    ) {
        #if DEBUG
        let nsError = error as NSError
        let roleLabel = role?.rawValue ?? "n/a"
        debugLog("[AuthService][\(context)] auth_failed email=\(maskedEmail(email)) role=\(roleLabel) uid=\(userId ?? "nil")")
        debugLog("[AuthService][\(context)] domain=\(nsError.domain) code=\(nsError.code)")
        debugLog("[AuthService][\(context)] localizedDescription=\(nsError.localizedDescription)")
        debugLog("[AuthService][\(context)] userInfo=\(nsError.userInfo)")

        for key in [
            "FIRAuthErrorUserInfoNameKey",
            "FIRAuthErrorUserInfoDeserializedResponseKey",
            "FIRAuthErrorUserInfoUpdatedCredentialKey"
        ] {
            if let value = nsError.userInfo[key] {
                debugLog("[AuthService][\(context)] \(key)=\(value)")
            }
        }

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

    private func signInWithCredentialAsync(_ credential: AuthCredential) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { continuation in
            auth.signIn(with: credential) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result else {
                    continuation.resume(throwing: AppError.invalidResponse)
                    return
                }
                continuation.resume(returning: result)
            }
        }
    }

    #if DEBUG
    func debugSignInProbe(email: String, password: String) async {
        do {
            try await signIn(email: email, password: password)
            debugLog("[AuthService][debugSignInProbe] success email=\(maskedEmail(email)) uid=\(auth.currentUser?.uid ?? "nil")")
        } catch {
            logNSErrorDetails(
                error,
                context: "debugSignInProbe",
                email: email,
                role: nil,
                userId: auth.currentUser?.uid
            )
        }
    }

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
