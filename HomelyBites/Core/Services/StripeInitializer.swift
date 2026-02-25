import Foundation
import StripePayments

enum StripeInitializer {
    static func configure() {
        let publishableKey = Bundle.main.infoDictionary?["STRIPE_PUBLISHABLE_KEY"] as? String ?? ""
        if publishableKey.isEmpty || publishableKey.hasPrefix("$(") {
            assertionFailure(AppError.stripePublishableKeyMissing.localizedDescription)
            return
        }
        StripeAPI.defaultPublishableKey = publishableKey
    }
}
