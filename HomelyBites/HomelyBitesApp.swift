// PREREQUIS : Signing & Capabilities -> Apple Pay -> ajouter merchant.com.homelybites
// PREREQUIS : Apple Developer Portal -> Certificates -> Merchant IDs -> creer merchant.com.homelybites
// PREREQUIS : Stripe Dashboard -> Settings -> Apple Pay -> uploader certificat Apple
// PREREQUIS : Tester sur device reel uniquement (Apple Pay = non disponible sur simulateur)
import SwiftUI
import StripePaymentSheet
import FirebaseCore
import FirebaseAuth
import GoogleSignIn


@main
struct HomelyBitesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var container: AppContainer
    @StateObject private var sessionViewModel: SessionViewModel

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        Self.logFirebaseBundleConfiguration()
        Self.logFirebaseRuntimeConfiguration()
        Self.logGoogleSignInConfiguration()
        Self.runDebugAuthResetIfRequested()
        Self.runDebugSignInProbeIfRequested()
        Self.runDebugSignUpProbeIfRequested()
        let key = Bundle.main.infoDictionary?["STRIPE_PUBLISHABLE_KEY"] as? String ?? ""
        StripeAPI.defaultPublishableKey = key
        let container = AppContainer()
        _container = StateObject(wrappedValue: container)
        _sessionViewModel = StateObject(wrappedValue: container.makeSessionViewModel())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
                .environmentObject(sessionViewModel)
                .onOpenURL { url in
                    if GIDSignIn.sharedInstance.handle(url) {
                        NSLog("%@", "[GOOGLE] handled callback URL")
                        return
                    }

                    Task {
                        await sessionViewModel.handleIncomingDeepLink(url)
                    }
                }
        }
    }

    private static func logFirebaseBundleConfiguration() {
        guard let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") else {
            NSLog("%@", "Firebase config error: GoogleService-Info.plist missing from bundle.")
            return
        }

        guard
            let plist = NSDictionary(contentsOfFile: plistPath),
            let plistBundleId = plist["BUNDLE_ID"] as? String,
            let appBundleId = Bundle.main.bundleIdentifier
        else {
            NSLog("%@", "Warning: Unable to read BUNDLE_ID from GoogleService-Info.plist.")
            return
        }

        if plistBundleId != appBundleId {
            NSLog("%@", "Firebase config INVALID: GoogleService-Info.plist BUNDLE_ID mismatch. plist.BUNDLE_ID=\(plistBundleId) app.bundleIdentifier=\(appBundleId). Download a new plist from Firebase Console > Project settings > Your apps > iOS (\(appBundleId)) and replace GoogleService-Info.plist.")
        } else {
            NSLog("%@", "Firebase plist bundle check OK: \(appBundleId)")
        }
    }

    private static func logGoogleSignInConfiguration() {
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            NSLog("%@", "Google Sign-In config warning: impossible de lire GoogleService-Info.plist.")
            return
        }

        guard let reversedClientId = FirebaseRuntimeConfig.reversedClientID() else {
            NSLog("%@", "Google Sign-In config warning: REVERSED_CLIENT_ID manquant dans GoogleService-Info.plist. Telecharge un plist iOS complet depuis Firebase Console.")
            return
        }

        if !isURLSchemeRegistered(reversedClientId) {
            NSLog("%@", "Google Sign-In config warning: URL scheme REVERSED_CLIENT_ID manquant dans Info.plist CFBundleURLTypes: \(reversedClientId)")
        } else {
            NSLog("%@", "[GOOGLE] URL scheme check OK: \(reversedClientId)")
        }

        let querySchemes = (Bundle.main.infoDictionary?["LSApplicationQueriesSchemes"] as? [String]) ?? []
        let querySet = Set(querySchemes.map { $0.lowercased() })
        let hasRequiredQuerySchemes = FirebaseRuntimeConfig.googleQuerySchemes.allSatisfy { scheme in
            querySet.contains(scheme)
        }
        if !hasRequiredQuerySchemes {
            NSLog("%@", "Google Sign-In config warning: LSApplicationQueriesSchemes devrait contenir google et com.google.")
        }
    }

    private static func logFirebaseRuntimeConfiguration() {
        if let runtimeClientId = FirebaseRuntimeConfig.googleClientID() {
            NSLog("%@", "[GOOGLE] runtime clientID OK: \(FirebaseRuntimeConfig.masked(runtimeClientId))")
        } else {
            NSLog("%@", "Google Sign-In config warning: clientID Firebase manquant. \(FirebaseRuntimeConfig.googleChecklist())")
        }
    }

    private static func isURLSchemeRegistered(_ scheme: String) -> Bool {
        guard let urlTypes = Bundle.main.infoDictionary?["CFBundleURLTypes"] as? [[String: Any]] else {
            return false
        }

        for entry in urlTypes {
            guard let schemes = entry["CFBundleURLSchemes"] as? [String] else {
                continue
            }
            if schemes.contains(where: { $0.caseInsensitiveCompare(scheme) == .orderedSame }) {
                return true
            }
        }
        return false
    }

    private static func runDebugSignUpProbeIfRequested() {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        NSLog("%@", "[HomelyBitesApp][debugProbe] env HB_DEBUG_SIGNUP_PROBE=\(env["HB_DEBUG_SIGNUP_PROBE"] ?? "nil")")
        guard env["HB_DEBUG_SIGNUP_PROBE"] == "1" else {
            return
        }

        let defaultEmail = "hb-probe+\(UUID().uuidString.prefix(8))@example.com"
        let email = env["HB_DEBUG_SIGNUP_EMAIL"] ?? defaultEmail
        let password = env["HB_DEBUG_SIGNUP_PASSWORD"] ?? "P@ssword1234!"
        let fullName = env["HB_DEBUG_SIGNUP_FULLNAME"] ?? "HB Debug Probe"
        let role = (env["HB_DEBUG_SIGNUP_ROLE"] ?? "client").lowercased() == "host" ? UserRole.host : UserRole.client

        NSLog("%@", "[HomelyBitesApp][debugProbe] requested email=\(email) role=\(role.rawValue)")
        Task {
            await AuthService().debugSignUpProbe(
                email: email,
                password: password,
                fullName: fullName,
                role: role
            )
        }
        #endif
    }

    private static func runDebugAuthResetIfRequested() {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        guard env["HB_DEBUG_AUTH_RESET"] == "1" else {
            return
        }

        do {
            try Auth.auth().signOut()
            NSLog("%@", "[HomelyBitesApp][debugAuthReset] signOut success")
        } catch {
            let nsError = error as NSError
            NSLog("%@", "[HomelyBitesApp][debugAuthReset] signOut failure domain=\(nsError.domain) code=\(nsError.code)")
            NSLog("%@", "[HomelyBitesApp][debugAuthReset] localizedDescription=\(nsError.localizedDescription)")
            NSLog("%@", "[HomelyBitesApp][debugAuthReset] userInfo=\(nsError.userInfo)")
        }
        #endif
    }

    private static func runDebugSignInProbeIfRequested() {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        guard env["HB_DEBUG_SIGNIN_PROBE"] == "1" else {
            return
        }

        let email = env["HB_DEBUG_SIGNIN_EMAIL"] ?? "hb-signin-probe@example.com"
        let password = env["HB_DEBUG_SIGNIN_PASSWORD"] ?? "P@ssword1234!"
        NSLog("%@", "[HomelyBitesApp][debugSignInProbe] requested email=\(email)")

        Task {
            await AuthService().debugSignInProbe(email: email, password: password)
        }
        #endif
    }
}
