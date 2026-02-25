import Foundation
import UIKit

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var fullName = ""
    @Published var bio = ""
    @Published var chefLevel: ChefLevel = .beginner
    @Published var photoURL: String?
    @Published var hasAcceptedHaccp = false
    @Published var haccpVersion = "2026-02"
    @Published var selectedImage: UIImage?
    @Published var isSaving = false
    @Published var isUploadingPhoto = false
    @Published var isAcknowledgingHaccp = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let firestoreService: FirestoreService
    private let storageService: StorageService
    private let functionsService: CloudFunctionsService

    init(
        firestoreService: FirestoreService = FirestoreService(),
        storageService: StorageService = StorageService(),
        functionsService: CloudFunctionsService = CloudFunctionsService()
    ) {
        self.firestoreService = firestoreService
        self.storageService = storageService
        self.functionsService = functionsService
    }

    func load(from user: AppUser) {
        fullName = user.fullName
        bio = user.bio ?? ""
        chefLevel = ChefLevel(rawValue: user.chefLevel ?? "") ?? .beginner
        photoURL = user.photoURL
        hasAcceptedHaccp = user.hasAcceptedHaccp
        if let haccpVersion = user.haccpVersion, !haccpVersion.isEmpty {
            self.haccpVersion = haccpVersion
        }
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
        let cleanedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
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
                fullName: cleanedName,
                bio: cleanedBio.isEmpty ? nil : cleanedBio,
                chefLevel: chefLevel.rawValue,
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

    func acknowledgeHaccp() async {
        isAcknowledgingHaccp = true
        defer { isAcknowledgingHaccp = false }

        do {
            try await functionsService.acknowledgeHaccp(version: haccpVersion)
            hasAcceptedHaccp = true
            successMessage = "Regles HACCP valides."
            #if DEBUG
            debugLog("[Profile][acknowledgeHaccp] success version=\(haccpVersion)")
            #endif
        } catch {
            #if DEBUG
            logNSErrorDetails(error, context: "acknowledgeHaccp")
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
