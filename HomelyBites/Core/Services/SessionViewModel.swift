import Foundation
import FirebaseAuth

@MainActor
final class SessionViewModel: ObservableObject {
    @Published private(set) var firebaseUser: User?
    @Published private(set) var appUser: AppUser?
    @Published var isBootstrapping = true
    @Published var globalErrorMessage: String?

    private let firestoreService: FirestoreService
    private let authService: AuthService
    private var authListenerHandle: AuthStateDidChangeListenerHandle?

    init(
        firestoreService: FirestoreService = FirestoreService(),
        authService: AuthService = AuthService()
    ) {
        self.firestoreService = firestoreService
        self.authService = authService
        startAuthListener()
    }

    deinit {
        if let authListenerHandle {
            Auth.auth().removeStateDidChangeListener(authListenerHandle)
        }
    }

    var isAuthenticated: Bool {
        firebaseUser != nil && appUser != nil
    }

    func signOut() {
        do {
            try authService.signOut()
        } catch {
            globalErrorMessage = error.localizedDescription
        }
    }

    func refreshUserProfile() async {
        guard let uid = firebaseUser?.uid else {
            appUser = nil
            return
        }

        do {
            appUser = try await firestoreService.fetchUser(uid: uid)
        } catch {
            globalErrorMessage = error.localizedDescription
        }
    }

    func handleIncomingDeepLink(_ url: URL) async {
        guard url.scheme == "homelybites", url.host == "onboarding" else {
            return
        }

        await refreshUserProfile()
    }

    private func startAuthListener() {
        #if DEBUG
        NSLog("🔄 [SessionViewModel] Starting auth state listener...")
        #endif

        authListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                #if DEBUG
                if let uid = user?.uid {
                    NSLog("✅ [SessionViewModel] Auth state changed - User authenticated: \(uid)")
                } else {
                    NSLog("⚠️ [SessionViewModel] Auth state changed - No user (signed out)")
                }
                #endif

                self.firebaseUser = user
                if let uid = user?.uid {
                    do {
                        #if DEBUG
                        NSLog("🔄 [SessionViewModel] Fetching user profile for uid: \(uid)")
                        #endif

                        self.appUser = try await self.firestoreService.fetchUser(uid: uid)

                        #if DEBUG
                        NSLog("✅ [SessionViewModel] User profile loaded: \(self.appUser?.fullName ?? "unknown")")
                        NSLog("✅ [SessionViewModel] User role: \(self.appUser?.role.rawValue ?? "unknown")")
                        #endif
                    } catch {
                        let nsError = error as NSError
                        #if DEBUG
                        NSLog("❌ [SessionViewModel] Failed to fetch user profile")
                        NSLog("❌ [SessionViewModel] Error: \(nsError.localizedDescription)")
                        #endif
                        self.appUser = nil
                        self.globalErrorMessage = error.localizedDescription
                    }
                } else {
                    self.appUser = nil
                }
                self.isBootstrapping = false

                #if DEBUG
                NSLog("✅ [SessionViewModel] Bootstrap complete. isAuthenticated: \(self.isAuthenticated)")
                #endif
            }
        }
    }
}
