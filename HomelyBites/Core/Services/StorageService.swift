import Foundation
import FirebaseStorage

struct UploadedMealPhoto {
    let downloadURL: String
    let storagePath: String
}

final class StorageService {
    private lazy var storage = Storage.storage()

    func uploadProfilePhoto(userId: String, imageData: Data) async throws -> String {
        let fileName = "\(UUID().uuidString).jpg"
        let path = "profilePhotos/\(userId)/\(fileName)"
        let reference = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        #if DEBUG
        debugLog("[StorageService][uploadProfilePhoto] start path=\(path) size=\(imageData.count)")
        #endif

        do {
            _ = try await upload(reference: reference, data: imageData, metadata: metadata)
            let url = try await downloadURL(reference: reference)
            #if DEBUG
            debugLog("[StorageService][uploadProfilePhoto] success path=\(path)")
            #endif
            return url.absoluteString
        } catch {
            #if DEBUG
            logNSErrorDetails(error, context: "uploadProfilePhoto", path: path)
            #endif
            throw error
        }
    }

    func uploadMealPhoto(hostId: String, mealId: String, imageData: Data) async throws -> UploadedMealPhoto {
        let fileName = "\(UUID().uuidString).jpg"
        let path = "mealPhotos/\(hostId)/\(mealId)/\(fileName)"
        let reference = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        #if DEBUG
        debugLog("[StorageService][uploadMealPhoto] start path=\(path) size=\(imageData.count)")
        #endif

        do {
            _ = try await upload(reference: reference, data: imageData, metadata: metadata)
            let url = try await downloadURL(reference: reference)
            #if DEBUG
            debugLog("[StorageService][uploadMealPhoto] success path=\(path)")
            #endif
            return UploadedMealPhoto(
                downloadURL: url.absoluteString,
                storagePath: path
            )
        } catch {
            #if DEBUG
            logNSErrorDetails(error, context: "uploadMealPhoto", path: path)
            #endif
            throw error
        }
    }

    private func upload(
        reference: StorageReference,
        data: Data,
        metadata: StorageMetadata
    ) async throws -> StorageMetadata {
        try await withCheckedThrowingContinuation { continuation in
            reference.putData(data, metadata: metadata) { metadata, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let metadata else {
                    continuation.resume(throwing: AppError.invalidResponse)
                    return
                }
                continuation.resume(returning: metadata)
            }
        }
    }

    private func downloadURL(reference: StorageReference) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            reference.downloadURL { url, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let url else {
                    continuation.resume(throwing: AppError.invalidResponse)
                    return
                }
                continuation.resume(returning: url)
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
        debugLog("[StorageService][\(context)] failed path=\(path)")
        debugLog("[StorageService][\(context)] domain=\(nsError.domain) code=\(nsError.code)")
        debugLog("[StorageService][\(context)] localizedDescription=\(nsError.localizedDescription)")
        debugLog("[StorageService][\(context)] userInfo=\(nsError.userInfo)")
        #endif
    }
}
