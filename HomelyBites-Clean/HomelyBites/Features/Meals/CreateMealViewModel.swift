import Foundation
import Observation

@Observable
@MainActor
final class CreateMealViewModel {
    var title = ""
    var description = ""
    var priceText = ""
    var availablePortions = 1
    var tagsText = ""
    var isSaving = false
    var errorMessage: String?
    var didSave = false

    private let service = FirestoreService()

    func createMeal(host: AppUser) async {
        // Validations
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Titre requis."; return
        }
        guard !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Description requise."; return
        }
        guard let price = Double(priceText.replacingOccurrences(of: ",", with: ".")),
              price > 0 else {
            errorMessage = "Prix invalide. Exemple : 12.50"; return
        }

        let priceCents = Int((price * 100).rounded())
        let tags = tagsText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        isSaving = true
        defer { isSaving = false }

        do {
            try await service.createMeal(
                host: host,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                priceCents: priceCents,
                availablePortions: availablePortions,
                tags: tags
            )
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
