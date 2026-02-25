import Foundation
import UIKit

@MainActor
final class CreateMealViewModel: ObservableObject {
    @Published var title = ""
    @Published var description = ""
    @Published var priceText = ""
    @Published var availablePortions = 1
    @Published var tagsText = ""
    @Published var serviceMode: MealServiceMode = .onSite
    @Published var selectedMealPhotoData: Data?
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var didSave = false

    private let firestoreService = FirestoreService()
    private let storageService = StorageService()

    func setSelectedMealPhotoData(_ data: Data?) {
        selectedMealPhotoData = data
    }

    func createMeal(host: AppUser) async {
        guard host.hasAcceptedHaccp else {
            errorMessage = "Validation HACCP obligatoire avant publication."
            return
        }

        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Titre requis."
            return
        }

        guard !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Description requise."
            return
        }

        guard let priceDouble = Double(priceText.replacingOccurrences(of: ",", with: ".")), priceDouble > 0 else {
            errorMessage = "Prix invalide. Exemple: 12.50"
            return
        }

        let priceCents = Int((priceDouble * 100.0).rounded())
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        isSaving = true
        defer { isSaving = false }

        do {
            let mealId = try await firestoreService.createMeal(
                host: host,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                priceCents: priceCents,
                availablePortions: availablePortions,
                tags: tags,
                serviceMode: serviceMode
            )

            if let selectedMealPhotoData {
                let optimizedPhotoData = try optimizeJPEGData(from: selectedMealPhotoData)
                let uploadedMealPhoto = try await storageService.uploadMealPhoto(
                    hostId: host.id,
                    mealId: mealId,
                    imageData: optimizedPhotoData
                )
                try await firestoreService.setMealPhoto(
                    mealId: mealId,
                    imageURL: uploadedMealPhoto.downloadURL,
                    imagePath: uploadedMealPhoto.storagePath
                )
            }
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func optimizeJPEGData(from data: Data) throws -> Data {
        guard let image = UIImage(data: data) else {
            throw AppError.invalidInput("Image repas invalide.")
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

        guard let jpeg = rendered.jpegData(compressionQuality: 0.82) else {
            throw AppError.invalidInput("Compression image repas impossible.")
        }
        return jpeg
    }
}
