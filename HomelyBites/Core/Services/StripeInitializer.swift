import Foundation
import StripePayments

enum StripeInitializer {
    static func configure() {
        let key = AppConfig.stripePublishableKey
        if key.isEmpty {
            assertionFailure(AppError.stripePublishableKeyMissing.localizedDescription)
            return
        }
        STPAPIClient.shared.publishableKey = key
    }
}
