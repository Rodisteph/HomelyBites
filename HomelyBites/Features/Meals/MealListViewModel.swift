import Foundation
import Observation

@Observable
@MainActor
final class MealListViewModel {
    var meals: [Meal] = []
    var isLoading = false
    var errorMessage: String?

    private let service = FirestoreService()

    func loadMeals() async {
        isLoading = true
        defer { isLoading = false }
        do { meals = try await service.fetchMeals() }
        catch { errorMessage = error.localizedDescription }
    }
}
