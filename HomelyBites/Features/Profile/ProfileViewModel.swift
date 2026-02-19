import Foundation
import UIKit

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var displayName = ""
    @Published var bio = ""
    @Published var chefLevel: ChefLevel = .beginner
    @Published var photoURL: String?
    @Published var selectedImage: UIImage?
    @Published var isSaving = false
    @Published var isUploadingPhoto = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let firestoreService: FirestoreService
    private let storageService: StorageService

    init(
        firestoreService: FirestoreService = FirestoreService(),
        storageService: StorageService = StorageService()
    ) {
        self.firestoreService = firestoreService
        self.storageService = storageService
    }

    func load(from user: AppUser) {
        displayName = user.displayName
        bio = user.bio
        chefLevel = user.chefLevel
        photoURL = user.photoURL
    }

    func uploadPhoto(userId: String, data: Data) async {
        isUploadingPhoto = true
        defer { isUploadingPhoto = false }

        do {
            guard let optimizedJPEGData = try optimizeJPEGData(from: data) else {
                throw AppError.invalidInput("Format photo non supporte.")
            }

            #if DEBUG
            debugLog("[Profile][photoUpload] start uid=\(userId) bytes=\(optimizedJPEGData.count)")
            #endif

            let uploadedURL = try await storageService.uploadProfilePhoto(
                userId: userId,
                imageData: optimizedJPEGData
            )
            photoURL = uploadedURL
            selectedImage = UIImage(data: optimizedJPEGData)
            successMessage = "Photo mise a jour."
        } catch {
            #if DEBUG
            logNSErrorDetails(error, context: "photoUpload")
            #endif
            errorMessage = error.localizedDescription
        }
    }

    func save(userId: String) async {
        let cleanedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedName.isEmpty else {
            errorMessage = "Le nom est obligatoire."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            try await firestoreService.updateUserProfile(
                uid: userId,
                displayName: cleanedName,
                bio: cleanedBio,
                chefLevel: chefLevel,
                photoURL: photoURL
            )
            successMessage = "Profil enregistre."
        } catch {
            #if DEBUG
            logNSErrorDetails(error, context: "saveProfile")
            #endif
            errorMessage = error.localizedDescription
        }
    }

    private func optimizeJPEGData(from data: Data) throws -> Data? {
        guard let image = UIImage(data: data) else {
            return nil
        }

        let maxDimension: CGFloat = 1600
        let size = image.size
        let largestSide = max(size.width, size.height)
        let ratio = largestSide > maxDimension ? (maxDimension / largestSide) : 1
        let resizedSize = CGSize(
            width: size.width * ratio,
            height: size.height * ratio
        )

        let renderer = UIGraphicsImageRenderer(size: resizedSize)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: resizedSize))
        }
        return rendered.jpegData(compressionQuality: 0.82)
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        NSLog("%@", message)
        #endif
    }

    private func logNSErrorDetails(_ error: Error, context: String) {
        #if DEBUG
        let nsError = error as NSError
        debugLog("[Profile][\(context)] domain=\(nsError.domain) code=\(nsError.code)")
        debugLog("[Profile][\(context)] localizedDescription=\(nsError.localizedDescription)")
        debugLog("[Profile][\(context)] userInfo=\(nsError.userInfo)")
        #endif
    }
}
