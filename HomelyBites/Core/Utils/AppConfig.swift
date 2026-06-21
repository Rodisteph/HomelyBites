import Foundation

enum AppConfig {
    static let firebaseFunctionsRegion = "europe-west1"

    static var stripePublishableKey: String {
        Bundle.main.object(forInfoDictionaryKey: "STRIPE_PUBLISHABLE_KEY") as? String ?? ""
    }
}
