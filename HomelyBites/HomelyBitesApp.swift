import SwiftUI
import StripeCore

@main
struct HomelyBitesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var sessionViewModel = SessionViewModel()

    init() {
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
