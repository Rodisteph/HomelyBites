import Foundation
import Observation

@Observable
@MainActor
final class MealDetailViewModel {
    var portions = 1
    var note = ""
    var isLoading = false
    var errorMessage: String?
    var createdOrderId: String?
    var confirmationInProgress = false

    let meal: Meal
    private let service = FirestoreService()

    init(meal: Meal) { self.meal = meal }

    var totalPriceCents: Int { meal.priceCents * portions }

    func reserveAndPay(clientId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let host = try await service.fetchUser(uid: meal.hostId)
            guard let stripeId = host.stripeAccountId, host.stripeOnboarded == true else {
                throw AppError.hostPaymentsNotReady
            }
            createdOrderId = try await service.createOrder(
                meal: meal, clientId: clientId,
                hostStripeAccountId: stripeId,
                portions: portions,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func paymentDidComplete() {
        createdOrderId = nil
        confirmationInProgress = true
    }
}
