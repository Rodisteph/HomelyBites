import SwiftUI
import StripeCore
import FirebaseCore


@main
struct HomelyBitesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var sessionViewModel = SessionViewModel()

    init() {
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") == nil {
            print("Warning: GoogleService-Info.plist not found in app bundle.")
        }
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        StripeInitializer.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(sessionViewModel)
                .onOpenURL { url in
                    Task {
                        await sessionViewModel.handleIncomingDeepLink(url)
                    }
                }
        }
    }
}
