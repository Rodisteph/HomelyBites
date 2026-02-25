import Foundation
import FirebaseFirestore

@MainActor
final class HostDashboardViewModel: ObservableObject {
    @Published var receivedOrders: [Order] = []
    @Published var hostMeals: [Meal] = []
    @Published var isLoading = false
    @Published var isActivatingPayments = false
    @Published var isRefreshingStripe = false
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

        #if DEBUG
        debugLog("[HostDashboard][activatePayments] start")
        #endif

        do {
            let session = try await functionsService.createConnectAccount()
            #if DEBUG
            debugLog("[HostDashboard][activatePayments] accountId=\(session.accountId) status=\(session.status) alreadyExists=\(session.alreadyExists)")
            #endif

            if let onboardingURLFromSession = session.onboardingURL {
                onboardingURL = onboardingURLFromSession
            } else if session.status != "enabled" {
                onboardingURL = try await functionsService.createOnboardingLink()
            } else {
                successMessage = "Paiements deja actifs."
            }
            #if DEBUG
            debugLog("[HostDashboard][activatePayments] onboardingURL=\(onboardingURL?.absoluteString ?? "nil")")
            #endif
        } catch {
            #if DEBUG
            logNSErrorDetails(error, context: "activatePayments")
            #endif
            errorMessage = error.localizedDescription
        }
    }

    func refreshStripeStatus() async {
        isRefreshingStripe = true
        defer { isRefreshingStripe = false }

        #if DEBUG
        debugLog("[HostDashboard][refreshStripeStatus] start")
        #endif

        do {
            let status = try await functionsService.refreshStripeStatus()
            successMessage = "Stripe: \(status.stripeStatus)"
            #if DEBUG
            debugLog("[HostDashboard][refreshStripeStatus] accountId=\(status.accountId) status=\(status.stripeStatus) onboarded=\(status.stripeOnboarded)")
            #endif
        } catch {
            #if DEBUG
            logNSErrorDetails(error, context: "refreshStripeStatus")
            #endif
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
        #if DEBUG
        debugLog("[HostDashboard][deleteMeal] requested index=\(index) mealId=\(hostMeals[index].id)")
        #endif
        pendingDeletionMeal = hostMeals[index]
    }

    func confirmMealDeletion(hostId: String) async {
        guard let meal = pendingDeletionMeal else { return }

        #if DEBUG
        debugLog("[HostDashboard][deleteMeal] confirm mealId=\(meal.id) hostId=\(hostId)")
        #endif

        isDeletingMeal = true
        defer {
            isDeletingMeal = false
            pendingDeletionMeal = nil
        }

        do {
            try await functionsService.deleteMeal(mealId: meal.id)
            hostMeals.removeAll { $0.id == meal.id }
            if !hostId.isEmpty {
                hostMeals = try await firestoreService.fetchMeals(hostId: hostId)
            }
            successMessage = "Plat supprime."
            #if DEBUG
            debugLog("[HostDashboard][deleteMeal] removed local mealId=\(meal.id)")
            #endif
        } catch {
            #if DEBUG
            logNSErrorDetails(error, context: "deleteMeal")
            #endif
            errorMessage = error.localizedDescription
        }
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        NSLog("%@", message)
        #endif
    }

    private func logNSErrorDetails(_ error: Error, context: String) {
        #if DEBUG
        let nsError = error as NSError
        debugLog("[HostDashboard][\(context)] domain=\(nsError.domain) code=\(nsError.code)")
        debugLog("[HostDashboard][\(context)] localizedDescription=\(nsError.localizedDescription)")
        debugLog("[HostDashboard][\(context)] userInfo=\(nsError.userInfo)")
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            debugLog("[HostDashboard][\(context)] underlying.domain=\(underlying.domain) code=\(underlying.code)")
            debugLog("[HostDashboard][\(context)] underlying.localizedDescription=\(underlying.localizedDescription)")
            debugLog("[HostDashboard][\(context)] underlying.userInfo=\(underlying.userInfo)")
        }
        #endif
    }
}
