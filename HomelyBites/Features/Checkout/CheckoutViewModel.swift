import Foundation
import StripePaymentSheet

@MainActor
final class CheckoutViewModel: ObservableObject {
    @Published var paymentSheet: PaymentSheet?
    @Published var isPreparing = false
    @Published var isPresentingPaymentSheet = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    let orderId: String

    private let functionsService = CloudFunctionsService()

    init(orderId: String) {
        self.orderId = orderId
    }

    func preparePaymentIfNeeded() async {
        if paymentSheet != nil {
            isPresentingPaymentSheet = true
            return
        }

        isPreparing = true
        defer { isPreparing = false }

        do {
            let clientSecret = try await functionsService.createPaymentIntentWithFee(orderId: orderId)

            var configuration = PaymentSheet.Configuration()
            configuration.merchantDisplayName = "HomelyBites"
            configuration.returnURL = "homelybites://stripe-redirect"
            configuration.allowsDelayedPaymentMethods = false

            paymentSheet = PaymentSheet(paymentIntentClientSecret: clientSecret, configuration: configuration)
            isPresentingPaymentSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func handlePaymentResult(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            statusMessage = "Paiement envoye. Confirmation en cours via webhook Stripe."
        case .canceled:
            statusMessage = "Paiement annule."
        case .failed(let error):
            errorMessage = error.localizedDescription
        }
    }
}
