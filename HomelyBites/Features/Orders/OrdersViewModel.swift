import Foundation
import FirebaseFirestore

@MainActor
final class OrdersViewModel: ObservableObject {
    @Published var orders: [Order] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let firestoreService = FirestoreService()
    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    func startListening(clientId: String) {
        guard listener == nil else { return }

        listener = firestoreService.listenClientOrders(clientId: clientId) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let orders):
                    self?.orders = orders
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func refresh(clientId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            orders = try await firestoreService.fetchClientOrders(clientId: clientId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
