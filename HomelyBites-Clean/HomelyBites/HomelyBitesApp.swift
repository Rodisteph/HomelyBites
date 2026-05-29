import SwiftUI
import FirebaseCore
import StripeCore

// 🔑 Point d'entrée.
// Firebase et Stripe initialisés ici directement —
// plus besoin d'un AppDelegate séparé juste pour ça.
@main
struct HomelyBitesApp: App {

    @State private var session = SessionViewModel()

    init() {
        FirebaseApp.configure()      // ← était dans AppDelegate.swift
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
