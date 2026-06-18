import SwiftUI
import FirebaseCore
import StripeCore

@main
struct HomelyBitesApp: App {

    @State private var session = SessionViewModel()

    init() {
        FirebaseApp.configure()
        StripeInitializer.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .onOpenURL { url in
                    Task { await session.handleIncomingDeepLink(url) }
                }
        }
    }
}
