import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Firestore Async helpers (sans FirebaseFirestoreSwift)
extension DocumentReference {

    /// Remplace setData(from:) (FirestoreSwift) par setData([String:Any])
    func setDataAsync(_ data: [String: Any], merge: Bool = false) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.setData(data, merge: merge) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func updateDataAsync(_ fields: [AnyHashable: Any]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.updateData(fields) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func getDocumentAsync() async throws -> DocumentSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            self.getDocument { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let snapshot else {
                    continuation.resume(throwing: AppError.invalidResponse)
                    return
                }
                continuation.resume(returning: snapshot)
            }
        }
    }

    func deleteAsync() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.delete { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

extension Query {
    func getDocumentsAsync() async throws -> QuerySnapshot {
        try await withCheckedThrowingContinuation { continuation in
            self.getDocuments { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let snapshot else {
                    continuation.resume(throwing: AppError.invalidResponse)
                    return
                }
                continuation.resume(returning: snapshot)
            }
        }
    }
}

extension Auth {
    func signInAsync(email: String, password: String) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { continuation in
            self.signIn(withEmail: email, password: password) { result, error in
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

    func createUserAsync(email: String, password: String) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { continuation in
            self.createUser(withEmail: email, password: password) { result, error in
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
}
