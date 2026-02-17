import Foundation

@MainActor
final class CreateMealViewModel: ObservableObject {
    @Published var title = ""
    @Published var description = ""
    @Published var priceText = ""
    @Published var availablePortions = 1
    @Published var tagsText = ""
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var didSave = false

    private let firestoreService = FirestoreService()

    func createMeal(host: AppUser) async {
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
            try await firestoreService.createMeal(
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
