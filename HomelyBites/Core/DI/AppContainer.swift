import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let authService: AuthService
    let firestoreService: FirestoreService
    let cloudFunctionsService: CloudFunctionsService

    init(
        authService: AuthService = AuthService(),
        firestoreService: FirestoreService = FirestoreService(),
        cloudFunctionsService: CloudFunctionsService = CloudFunctionsService()
    ) {
        self.authService = authService
        self.firestoreService = firestoreService
        self.cloudFunctionsService = cloudFunctionsService
    }

    func makeSessionViewModel() -> SessionViewModel {
        SessionViewModel(
            firestoreService: firestoreService,
            authService: authService
        )
    }
}
