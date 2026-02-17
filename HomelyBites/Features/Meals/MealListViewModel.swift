import Foundation

@MainActor
final class MealListViewModel: ObservableObject {
    @Published var meals: [Meal] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let firestoreService = FirestoreService()

    func loadMeals() async {
        isLoading = true
        defer { isLoading = false }

        do {
            meals = try await firestoreService.fetchMeals()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
