import Foundation
import PassKit

@MainActor
final class CheckoutViewModel: ObservableObject {
    @Published var isPreparing = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?
    @Published var paymentSucceeded = false

    let orderId: String
    let amountCents: Int
    let itemLabel: String

    private let functionsService: CloudFunctionsService

    init(
        orderId: String,
        amountCents: Int,
        itemLabel: String,
        functionsService: CloudFunctionsService = CloudFunctionsService()
    ) {
        self.orderId = orderId
        self.amountCents = amountCents
        self.itemLabel = itemLabel
        self.functionsService = functionsService
    }

    func handleApplePayToken(_ token: PKPaymentToken) async {
        isPreparing = true
        defer { isPreparing = false }

        #if DEBUG
        debugLog("[Checkout][handleApplePayToken] start orderId=\(orderId)")
        #endif

        do {
            let tokenData = token.paymentData
            let tokenString = tokenData.base64EncodedString()

            try await functionsService.confirmPaymentWithApplePay(
                orderId: orderId,
                applePayToken: tokenString
            )

            statusMessage = "Paiement confirmé. Consultez l'onglet Commandes."
            paymentSucceeded = true

            #if DEBUG
            debugLog("[Checkout][handleApplePayToken] success orderId=\(orderId)")
            #endif
        } catch {
            #if DEBUG
            logNSErrorDetails(error, context: "handleApplePayToken")
            #endif
            errorMessage = error.localizedDescription
        }
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
