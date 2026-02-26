import Foundation

enum AppConfig {
    static let firebaseFunctionsRegion = "europe-west1"
    static let stripeReturnURL = "homelybites://onboarding/return"
    static let stripeRefreshURL = "homelybites://onboarding/refresh"
    static let appleMerchantIdentifier = "merchant.com.homelybites.app"
    static let privacyPolicyURL = URL(string: "https://homelybites.app/privacy")!
    static let termsOfUseURL = URL(string: "https://homelybites.app/terms")!

    static var stripePublishableKey: String {
        Bundle.main.object(forInfoDictionaryKey: "STRIPE_PUBLISHABLE_KEY") as? String ?? ""
    }
}
