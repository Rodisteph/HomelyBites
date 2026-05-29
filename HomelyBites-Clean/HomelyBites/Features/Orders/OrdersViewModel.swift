import Foundation
import Observation
import FirebaseFirestore

@Observable
@MainActor
final class OrdersViewModel {
    var orders: [Order] = []
    var isLoading = false
    var errorMessage: String?

    private let service = FirestoreService()
    @ObservationIgnored private var listener: ListenerRegistration?

    deinit { listener?.remove() }

    func startListening(clientId: String) {
        guard listener == nil else { return }
        listener = service.listenClientOrders(clientId: clientId) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let orders): self?.orders = orders
                case .failure(let error):  self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func refresh(clientId: String) async {
        isLoading = true
        defer { isLoading = false }
        do { orders = try await service.fetchClientOrders(clientId: clientId) }
        catch { errorMessage = error.localizedDescription }
    }
}
