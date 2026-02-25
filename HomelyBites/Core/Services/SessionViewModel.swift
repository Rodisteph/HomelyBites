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
        authListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                self.firebaseUser = user
                if let uid = user?.uid {
                    do {
                        self.appUser = try await self.firestoreService.fetchUser(uid: uid)
                    } catch {
                        self.appUser = nil
                        self.globalErrorMessage = error.localizedDescription
                    }
                } else {
                    self.appUser = nil
                }
                self.isBootstrapping = false
            }
        }
    }
}
