import Foundation
import StripePayments

enum StripeInitializer {
    static func configure() {
        let key = AppConfig.stripePublishableKey
        guard !key.isEmpty else {
            assertionFailure(AppError.stripePublishableKeyMissing.localizedDescription)
            return
        }
        STPAPIClient.shared.publishableKey = key
    }
}
