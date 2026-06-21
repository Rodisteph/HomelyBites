import Foundation
import Observation
import FirebaseFirestore

@Observable
@MainActor
final class HostDashboardViewModel {
    var receivedOrders: [Order] = []
    var isLoading = false
    var errorMessage: String?
    var successMessage: String?
    var showingCreateMeal = false

    private let firestoreService = FirestoreService()
    @ObservationIgnored private var listener: ListenerRegistration?

    deinit { listener?.remove() }

    func startListening(hostId: String) {
        guard listener == nil else { return }
        listener = firestoreService.listenHostOrders(hostId: hostId) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let orders): self?.receivedOrders = orders
                case .failure(let error):  self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func refresh(hostId: String) async {
        isLoading = true
        defer { isLoading = false }
        do { receivedOrders = try await firestoreService.fetchHostOrders(hostId: hostId) }
        catch { errorMessage = error.localizedDescription }
    }

    func updateOrderStatus(orderId: String, status: OrderStatus) async {
        do { try await firestoreService.updateOrderStatus(orderId: orderId, status: status) }
        catch { errorMessage = error.localizedDescription }
    }

    func seedMeals(host: AppUser) async {
        do {
            try await firestoreService.createDemoMeals(host: host)
            successMessage = "2 repas de test crees."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
