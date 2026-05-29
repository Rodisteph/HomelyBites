import Foundation

enum AppConfig {
    static let firebaseFunctionsRegion = "europe-west1"
    static let stripeReturnURL  = "homelybites://onboarding/return"
    static let stripeRefreshURL = "homelybites://onboarding/refresh"

    static var stripePublishableKey: String {
        Bundle.main.object(forInfoDictionaryKey: "STRIPE_PUBLISHABLE_KEY") as? String ?? ""
    }
}
