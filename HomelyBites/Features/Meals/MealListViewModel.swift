import Foundation
import FirebaseAuth

@MainActor
final class MealListViewModel: ObservableObject {
    @Published var meals: [Meal] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let firestoreService = FirestoreService()

    func loadMeals() async {
        #if DEBUG
        NSLog("🔄 [MealListViewModel] Starting to fetch meals...")
        NSLog("🔄 [MealListViewModel] Auth user: \(Auth.auth().currentUser?.uid ?? "nil")")
        #endif

        isLoading = true
        defer { isLoading = false }

        do {
            let fetchedMeals = try await firestoreService.fetchMeals()
            meals = fetchedMeals

            #if DEBUG
            NSLog("✅ [MealListViewModel] Successfully fetched \(meals.count) meals")
            if !meals.isEmpty {
                NSLog("✅ [MealListViewModel] First meal: \(meals[0].title)")
            }
            #endif
        } catch {
            let nsError = error as NSError
            #if DEBUG
            NSLog("❌ [MealListViewModel] Failed to fetch meals")
            NSLog("❌ [MealListViewModel] Error domain: \(nsError.domain)")
            NSLog("❌ [MealListViewModel] Error code: \(nsError.code)")
            NSLog("❌ [MealListViewModel] Error description: \(nsError.localizedDescription)")
            NSLog("❌ [MealListViewModel] Error userInfo: \(nsError.userInfo)")
            #endif
            errorMessage = error.localizedDescription
        }
    }
}
