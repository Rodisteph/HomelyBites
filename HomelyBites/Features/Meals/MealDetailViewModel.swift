import Foundation

@MainActor
final class MealDetailViewModel: ObservableObject {
    @Published var portions = 1
    @Published var note = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var createdOrderId: String?
    @Published var confirmationInProgress = false

    let meal: Meal

    private let firestoreService = FirestoreService()

    init(meal: Meal) {
        self.meal = meal
    }

    func reserveAndPay(clientId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let hostProfile = try await firestoreService.fetchUser(uid: meal.hostId)
            guard let stripeAccountId = hostProfile.stripeAccountId,
                  hostProfile.stripeOnboarded == true else {
                throw AppError.hostPaymentsNotReady
            }

            let orderId = try await firestoreService.createOrder(
                meal: meal,
                clientId: clientId,
                hostStripeAccountId: stripeAccountId,
                portions: portions,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            createdOrderId = orderId
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func paymentDidComplete() {
        createdOrderId = nil
        confirmationInProgress = true
    }

    var totalPriceCents: Int {
        meal.priceCents * portions
    }
}
