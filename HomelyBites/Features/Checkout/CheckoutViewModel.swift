import Foundation
import Observation
import StripePaymentSheet

@Observable
@MainActor
final class CheckoutViewModel {
    var paymentSheet: PaymentSheet?
    var isPreparing = false
    var isPresentingPaymentSheet = false
    var statusMessage: String?
    var errorMessage: String?

    let orderId: String
    private let service = CloudFunctionsService()

    init(orderId: String) { self.orderId = orderId }

    func preparePaymentIfNeeded() async {
        if paymentSheet != nil { isPresentingPaymentSheet = true; return }

        isPreparing = true
        defer { isPreparing = false }

        do {
            let clientSecret = try await service.createPaymentIntentWithFee(orderId: orderId)

            var config = PaymentSheet.Configuration()
            config.merchantDisplayName = "HomelyBites"
            config.returnURL = "homelybites://stripe-redirect"
            config.allowsDelayedPaymentMethods = false

            paymentSheet = PaymentSheet(paymentIntentClientSecret: clientSecret, configuration: config)
            isPresentingPaymentSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func handlePaymentResult(_ result: PaymentSheetResult) {
        switch result {
        case .completed: statusMessage = "Paiement envoye. Confirmation via webhook Stripe."
        case .canceled:  statusMessage = "Paiement annule."
        case .failed(let error): errorMessage = error.localizedDescription
        }
    }
}
