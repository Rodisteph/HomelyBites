import Foundation
import FirebaseFirestore
import FirebaseAuth

extension DocumentReference {
    func setDataAsync(_ fields: [String: Any], merge: Bool = false) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.setData(fields, merge: merge) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func setData<T: Encodable>(from value: T, merge: Bool = false) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
                try self.setData(from: value, merge: merge) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    func getDocument<T: Decodable>(as type: T.Type) async throws -> T {
        let snapshot = try await getDocumentAsync()
        return try snapshot.data(as: T.self)
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

    func updateDataAsync(_ fields: [String: Any]) async throws {
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
    func getDocuments<T: Decodable>(as type: T.Type) async throws -> [T] {
        let snapshot = try await getDocumentsAsync()
        return try snapshot.documents.map { try $0.data(as: T.self) }
    }

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
                    continuation.resume(throwing: error ?? AppError.invalidResponse)
                    return
                }
                continuation.resume(returning: result)
            }
        }
    }
}
