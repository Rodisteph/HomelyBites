import Foundation
import Observation
import FirebaseAuth

// 🏠 ViewModel global partagé via .environment.
// Déplacé depuis Core/Services/ → Features/Root/ car c'est un ViewModel, pas un Service.
@Observable
@MainActor
final class SessionViewModel {

    private(set) var firebaseUser: User?
    private(set) var appUser: AppUser?
    var isBootstrapping = true
    var globalErrorMessage: String?

    private let firestoreService = FirestoreService()
    private let authService      = AuthService()
    @ObservationIgnored private var authListenerHandle: AuthStateDidChangeListenerHandle?

    init() { startAuthListener() }

    deinit {
        if let authListenerHandle {
            Auth.auth().removeStateDidChangeListener(authListenerHandle)
        }
    }

    var isAuthenticated: Bool { firebaseUser != nil && appUser != nil }

    func signOut() {
        do { try authService.signOut() }
        catch { globalErrorMessage = error.localizedDescription }
    }

    func refreshUserProfile() async {
        guard let uid = firebaseUser?.uid else { appUser = nil; return }
        do { appUser = try await firestoreService.fetchUser(uid: uid) }
        catch { globalErrorMessage = error.localizedDescription }
    }

    func handleIncomingDeepLink(_ url: URL) async {
        guard url.scheme == "homelybites", url.host == "onboarding" else { return }
        await refreshUserProfile()
    }

    // MARK: - Privé

    private func startAuthListener() {
        authListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                self.firebaseUser = user
                if let uid = user?.uid {
                    do { self.appUser = try await self.firestoreService.fetchUser(uid: uid) }
                    catch { self.appUser = nil; self.globalErrorMessage = error.localizedDescription }
                } else {
                    self.appUser = nil
                }
                self.isBootstrapping = false
            }
        }
    }
}
