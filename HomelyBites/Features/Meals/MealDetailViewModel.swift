import Foundation
import FirebaseAuth
import PassKit

@MainActor
final class MealDetailViewModel: ObservableObject {
    @Published var portions = 1
    @Published var note = ""
    @Published var selectedServiceMode: MealServiceMode
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var checkoutSession: OrderCheckoutSession?
    @Published var confirmationInProgress = false

    let meal: Meal

    private let functionsService: CloudFunctionsService

    init(
        meal: Meal,
        functionsService: CloudFunctionsService = CloudFunctionsService()
    ) {
        self.meal = meal
        self.functionsService = functionsService
        self.selectedServiceMode = meal.availableServiceModes.first ?? .onSite
    }

    func reserveAndPay() async {
        guard let currentUser = Auth.auth().currentUser else {
            errorMessage = AppError.missingAuth.localizedDescription
            #if DEBUG
            debugLog("[MealDetail][reserveAndPay] blocked: no authenticated user")
            #endif
            return
        }

        isLoading = true
        defer { isLoading = false }

        #if DEBUG
        debugLog("[MealDetail][reserveAndPay] start uid=\(currentUser.uid) mealId=\(meal.id) portions=\(portions) total=\(totalPriceCents)")
        #endif

        do {
            let session = try await functionsService.createOrderAndPaymentIntent(
                mealId: meal.id,
                portions: portions,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                serviceMode: selectedServiceMode
            )
            checkoutSession = session
            #if DEBUG
            debugLog("[MealDetail][reserveAndPay] success orderId=\(session.orderId)")
            #endif
        } catch {
            #if DEBUG
            logNSErrorDetails(error, context: "reserveAndPay")
            #endif
            errorMessage = error.localizedDescription
        }
    }

    func reserveWithApplePay(token: PKPaymentToken) async {
        guard let currentUser = Auth.auth().currentUser else {
            errorMessage = AppError.missingAuth.localizedDescription
            #if DEBUG
            debugLog("[MealDetail][reserveWithApplePay] blocked: no authenticated user")
            #endif
            return
        }

        isLoading = true
        defer { isLoading = false }

        #if DEBUG
        debugLog("[MealDetail][reserveWithApplePay] start uid=\(currentUser.uid) mealId=\(meal.id) portions=\(portions)")
        #endif

        do {
            // Step 1: Create order and payment intent
            let session = try await functionsService.createOrderAndPaymentIntent(
                mealId: meal.id,
                portions: portions,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                serviceMode: selectedServiceMode
            )

            #if DEBUG
            debugLog("[MealDetail][reserveWithApplePay] order created orderId=\(session.orderId)")
            #endif

            // Step 2: Convert PKPaymentToken to base64 string
            let tokenData = token.paymentData
            let tokenString = tokenData.base64EncodedString()

            // Step 3: Confirm payment with Apple Pay token
            try await functionsService.confirmPaymentWithApplePay(
                orderId: session.orderId,
                applePayToken: tokenString
            )

            #if DEBUG
            debugLog("[MealDetail][reserveWithApplePay] payment confirmed orderId=\(session.orderId)")
            #endif

            // Mark as completed
            confirmationInProgress = true

        } catch {
            #if DEBUG
            logNSErrorDetails(error, context: "reserveWithApplePay")
            #endif
            errorMessage = error.localizedDescription
        }
    }

    func paymentDidComplete() {
        checkoutSession = nil
        confirmationInProgress = true
    }

    var totalPriceCents: Int {
        meal.priceCents * portions
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        NSLog("%@", message)
        #endif
    }

    private func logNSErrorDetails(_ error: Error, context: String) {
        #if DEBUG
        let nsError = error as NSError
        debugLog("[MealDetail][\(context)] domain=\(nsError.domain) code=\(nsError.code)")
        debugLog("[MealDetail][\(context)] localizedDescription=\(nsError.localizedDescription)")
        debugLog("[MealDetail][\(context)] userInfo=\(nsError.userInfo)")
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            debugLog("[MealDetail][\(context)] underlying.domain=\(underlying.domain) code=\(underlying.code)")
            debugLog("[MealDetail][\(context)] underlying.localizedDescription=\(underlying.localizedDescription)")
            debugLog("[MealDetail][\(context)] underlying.userInfo=\(underlying.userInfo)")
        }
        #endif
    }
}
