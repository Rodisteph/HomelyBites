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
    private let clientSecret: String

    init(orderId: String, clientSecret: String) {
        self.orderId = orderId
        self.clientSecret = clientSecret
    }

    func preparePaymentIfNeeded() async {
        if paymentSheet != nil {
            isPresentingPaymentSheet = true
            return
        }

        isPreparing = true
        defer { isPreparing = false }

        #if DEBUG
        debugLog("[Checkout][preparePayment] start orderId=\(orderId) clientSecret=\(redacted(clientSecret))")
        #endif

        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = "HomelyBites"
        configuration.returnURL = "homelybites://stripe-redirect"
        configuration.allowsDelayedPaymentMethods = false

        paymentSheet = PaymentSheet(paymentIntentClientSecret: clientSecret, configuration: configuration)
        isPresentingPaymentSheet = true

        #if DEBUG
        debugLog("[Checkout][preparePayment] paymentSheet ready")
        #endif
    }

    func handlePaymentResult(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            statusMessage = "Paiement envoye. Confirmation en cours via webhook Stripe."
            #if DEBUG
            debugLog("[Checkout][handlePaymentResult] completed orderId=\(orderId)")
            #endif
        case .canceled:
            statusMessage = "Paiement annule."
            #if DEBUG
            debugLog("[Checkout][handlePaymentResult] canceled orderId=\(orderId)")
            #endif
        case .failed(let error):
            #if DEBUG
            logNSErrorDetails(error, context: "handlePaymentResult")
            #endif
            errorMessage = error.localizedDescription
        }
    }

    private func redacted(_ value: String) -> String {
        guard value.count > 12 else {
            return "***"
        }
        return "\(value.prefix(8))...\(value.suffix(4))"
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        NSLog("%@", message)
        #endif
    }

    private func logNSErrorDetails(_ error: Error, context: String) {
        #if DEBUG
        let nsError = error as NSError
        debugLog("[Checkout][\(context)] domain=\(nsError.domain) code=\(nsError.code)")
        debugLog("[Checkout][\(context)] localizedDescription=\(nsError.localizedDescription)")
        debugLog("[Checkout][\(context)] userInfo=\(nsError.userInfo)")
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            debugLog("[Checkout][\(context)] underlying.domain=\(underlying.domain) code=\(underlying.code)")
            debugLog("[Checkout][\(context)] underlying.localizedDescription=\(underlying.localizedDescription)")
            debugLog("[Checkout][\(context)] underlying.userInfo=\(underlying.userInfo)")
        }
        #endif
    }
}
