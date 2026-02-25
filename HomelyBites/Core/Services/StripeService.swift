// PREREQUIS : Signing & Capabilities -> Apple Pay -> ajouter merchant.com.homelybites
// PREREQUIS : Apple Developer Portal -> Certificates -> Merchant IDs -> creer merchant.com.homelybites
// PREREQUIS : Stripe Dashboard -> Settings -> Apple Pay -> uploader certificat Apple
// PREREQUIS : Tester sur device reel uniquement (Apple Pay = non disponible sur simulateur)
import Foundation
import StripePaymentSheet

enum StripeService {
    private static let merchantId = "merchant.com.homelybites"
    private static let merchantCountryCode = "FR"
    private static let merchantCurrency = "eur"

    static func configurePublishableKey() {
        let publishableKey = Bundle.main.infoDictionary?["STRIPE_PUBLISHABLE_KEY"] as? String ?? ""
        StripeAPI.defaultPublishableKey = publishableKey
    }

    static var isApplePayAvailable: Bool {
        StripeAPI.deviceSupportsApplePay()
    }

    static func makePaymentSheetConfiguration() -> PaymentSheet.Configuration {
        var config = PaymentSheet.Configuration()
        config.merchantDisplayName = "HomelyBites"
        config.returnURL = "homelybites://stripe-redirect"
        config.allowsDelayedPaymentMethods = false
        config.applePay = .init(
            merchantId: merchantId,
            merchantCountryCode: merchantCountryCode,
            buttonType: .buy,
            customHandlers: .init(paymentRequestHandler: { request in
                let paymentRequest = request
                paymentRequest.currencyCode = merchantCurrency.uppercased()
                return paymentRequest
            })
        )
        return config
    }

    static func makePaymentSheet(paymentIntentClientSecret: String) -> PaymentSheet {
        PaymentSheet(
            paymentIntentClientSecret: paymentIntentClientSecret,
            configuration: makePaymentSheetConfiguration()
        )
    }
}
