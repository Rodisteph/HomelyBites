import Foundation
import FirebaseFirestore

@MainActor
final class HostDashboardViewModel: ObservableObject {
    @Published var receivedOrders: [Order] = []
    @Published var hostMeals: [Meal] = []
    @Published var isLoading = false
    @Published var isActivatingPayments = false
    @Published var isDeletingMeal = false
    @Published var onboardingURL: URL?
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var showingCreateMeal = false
    @Published var pendingDeletionMeal: Meal?

    private let firestoreService: FirestoreService
    private let functionsService: CloudFunctionsService
    private var listener: ListenerRegistration?
    private var currentHostId: String?

    init(
        firestoreService: FirestoreService = FirestoreService(),
        functionsService: CloudFunctionsService = CloudFunctionsService()
    ) {
        self.firestoreService = firestoreService
        self.functionsService = functionsService
    }

    deinit {
        listener?.remove()
    }

    func startListening(hostId: String) {
        currentHostId = hostId
        guard listener == nil else { return }

        listener = firestoreService.listenHostOrders(hostId: hostId) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let orders):
                    self?.receivedOrders = orders
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func refresh(hostId: String) async {
        currentHostId = hostId
        isLoading = true
        defer { isLoading = false }

        do {
            async let orders = firestoreService.fetchHostOrders(hostId: hostId)
            async let meals = firestoreService.fetchMeals(hostId: hostId)
            receivedOrders = try await orders
            hostMeals = try await meals
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func activatePayments() async {
        isActivatingPayments = true
        defer { isActivatingPayments = false }

        do {
            _ = try await functionsService.createConnectAccount()
            onboardingURL = try await functionsService.createOnboardingLink()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateOrderStatus(orderId: String, status: OrderStatus) async {
        do {
            try await functionsService.transitionOrderStatus(orderId: orderId, to: status)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func seedMeals(host: AppUser) async {
        do {
            try await firestoreService.createDemoMeals(host: host)
            successMessage = "2 meals de test crees."
            if let hostId = currentHostId {
                hostMeals = try await firestoreService.fetchMeals(hostId: hostId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestMealDeletion(at offsets: IndexSet) {
        guard let index = offsets.first, hostMeals.indices.contains(index) else { return }
        pendingDeletionMeal = hostMeals[index]
    }

    func confirmMealDeletion(hostId: String) async {
        guard let meal = pendingDeletionMeal else { return }

        isDeletingMeal = true
        defer {
            isDeletingMeal = false
            pendingDeletionMeal = nil
        }

        do {
            try await firestoreService.deleteMeal(mealId: meal.id, hostId: hostId)
            hostMeals.removeAll { $0.id == meal.id }
            successMessage = "Plat supprime."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
