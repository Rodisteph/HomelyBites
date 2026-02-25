import Foundation
import StripeCore

enum StripeInitializer {
    static func configure() {
        // Clé publishable Stripe — utilisée uniquement pour identifier
        // le marchand côté client. Le vrai travail se fait côté serveur.
        #if DEBUG
        if let key = Bundle.main.infoDictionary?["STRIPE_PUBLISHABLE_KEY"] as? String, !key.isEmpty {
            StripeAPI.defaultPublishableKey = key
            NSLog("[Stripe] Configured with publishable key (DEBUG mode)")
        } else {
            NSLog("[Stripe] ⚠️ STRIPE_PUBLISHABLE_KEY not found in Info.plist")
        }
        #else
        if let key = Bundle.main.infoDictionary?["STRIPE_PUBLISHABLE_KEY"] as? String, !key.isEmpty {
            StripeAPI.defaultPublishableKey = key
        }
        #endif
    }
}
