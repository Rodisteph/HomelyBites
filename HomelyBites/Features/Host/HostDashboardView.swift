import SwiftUI

struct HostDashboardView: View {
    @EnvironmentObject private var session: SessionViewModel
    @StateObject private var viewModel: HostDashboardViewModel

    init(
        firestoreService: FirestoreService = FirestoreService(),
        functionsService: CloudFunctionsService = CloudFunctionsService()
    ) {
        _viewModel = StateObject(
            wrappedValue: HostDashboardViewModel(
                firestoreService: firestoreService,
                functionsService: functionsService
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let user = session.appUser {
                    welcomeHeader(for: user)

                    stripeStatusCard(for: user)

                    mealsSection(for: user)

                    ordersSection
                }
            }
            .padding(.vertical, 20)
        }
        .background(AppColors.cream)
        .navigationTitle("Tableau de bord")
        .task {
            guard let hostId = session.appUser?.id else { return }
            viewModel.startListening(hostId: hostId)
            if viewModel.receivedOrders.isEmpty {
                await viewModel.refresh(hostId: hostId)
            }
        }
        .refreshable {
            guard let hostId = session.appUser?.id else { return }
            await viewModel.refresh(hostId: hostId)
            await session.refreshUserProfile()
        }
        .sheet(
            isPresented: $viewModel.showingCreateMeal,
            onDismiss: {
                guard let hostId = session.appUser?.id else { return }
                Task {
                    await viewModel.refresh(hostId: hostId)
                }
            }
        ) {
            if let user = session.appUser {
                CreateMealView(host: user)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.onboardingURL != nil },
                set: { if !$0 { viewModel.onboardingURL = nil } }
            )
        ) {
            if let onboardingURL = viewModel.onboardingURL {
                SafariView(url: onboardingURL)
            }
        }
        .alert(
            "Erreur",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            ),
            actions: {
                Button("OK", role: .cancel) {}
            },
            message: {
                Text(viewModel.errorMessage ?? "")
            }
        )
        .alert(
            "Supprimer ce plat ?",
            isPresented: Binding(
                get: { viewModel.pendingDeletionMeal != nil },
                set: { if !$0 { viewModel.pendingDeletionMeal = nil } }
            ),
            presenting: viewModel.pendingDeletionMeal
        ) { meal in
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) {
                guard let hostId = session.appUser?.id else { return }
                Task {
                    await viewModel.confirmMealDeletion(hostId: hostId)
                }
            }
            .disabled(viewModel.isDeletingMeal)
        } message: { meal in
            Text("Le plat \"\(meal.title)\" sera supprimé définitivement.")
        }
    }

    // MARK: - View Builders
    @ViewBuilder
    private func welcomeHeader(for user: AppUser) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bienvenue, \(user.fullName)")
                .font(.cormorantDisplay(28, weight: .semibold))
                .foregroundStyle(AppColors.charcoal)
            Text("Espace hôte")
                .font(.bodyLarge)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func stripeStatusCard(for user: AppUser) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Paiements")
                .font(.headlineSmall)
                .foregroundStyle(AppColors.charcoal)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Statut paiements")
                        .font(.bodyMedium)
                        .foregroundStyle(AppColors.textSecondary)
                    Text(user.isStripeReady ? "Activé" : "Non activé")
                        .font(.dmSans(16, weight: .semibold))
                        .foregroundStyle(user.isStripeReady ? AppColors.success : AppColors.warning)
                }
                Spacer()
                StatusBadge(type: user.isStripeReady ? .completed : .pending)
            }

            Button {
                Task {
                    await viewModel.activatePayments()
                }
            } label: {
                if viewModel.isActivatingPayments {
                    HStack {
                        ProgressView()
                            .tint(.white)
                        Text("Ouverture Stripe...")
                    }
                } else {
                    Text("Activer paiements")
                }
            }
            .buttonStyle(PrimaryButtonStyle(isLoading: viewModel.isActivatingPayments))

            Button {
                Task {
                    await viewModel.refreshStripeStatus()
                    await session.refreshUserProfile()
                }
            } label: {
                Text("Rafraîchir profil Stripe")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(16)
        .appCard()
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func mealsSection(for user: AppUser) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Mes plats")
                    .font(.headlineMedium)
                    .foregroundStyle(AppColors.charcoal)
                Spacer()
                Button {
                    viewModel.showingCreateMeal = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(AppColors.terracotta)
                }
            }

            if let successMessage = viewModel.successMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(successMessage)
                        .font(.bodyMedium)
                }
                .foregroundStyle(AppColors.success)
            }

            if viewModel.hostMeals.isEmpty {
                VStack(spacing: 12) {
                    Text("Aucun plat publié pour le moment.")
                        .font(.bodyMedium)
                        .foregroundStyle(AppColors.textSecondary)

                    #if DEBUG
                    Button("Créer 2 plats de test") {
                        Task {
                            await viewModel.seedMeals(host: user)
                        }
                    }
                    .font(.labelLarge)
                    .foregroundStyle(AppColors.terracotta)
                    #endif
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.creamDark)
                )
            } else {
                ForEach(viewModel.hostMeals) { meal in
                    MealCardView(meal: meal)
                }
                .onDelete { offsets in
                    viewModel.requestMealDeletion(at: offsets)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var ordersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Commandes reçues")
                .font(.headlineMedium)
                .foregroundStyle(AppColors.charcoal)

            if viewModel.receivedOrders.isEmpty {
                Text("Aucune commande pour le moment.")
                    .font(.bodyMedium)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.creamDark)
                    )
            } else {
                ForEach(viewModel.receivedOrders) { order in
                    HostOrderRow(
                        order: order,
                        onConfirm: {
                            guard let orderId = order.id else { return }
                            Task { await viewModel.updateOrderStatus(orderId: orderId, status: .confirmed) }
                        },
                        onReject: {
                            guard let orderId = order.id else { return }
                            Task { await viewModel.updateOrderStatus(orderId: orderId, status: .rejected) }
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

private struct MealCardView: View {
    let meal: Meal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(meal.title)
                        .font(.cormorantDisplay(20, weight: .semibold))
                        .foregroundStyle(AppColors.charcoal)
                    Text("Portions disponibles: \(meal.availablePortions)")
                        .font(.labelMedium)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                Text(meal.priceCents.asEuro())
                    .font(.dmSans(18, weight: .bold))
                    .foregroundStyle(AppColors.terracotta)
            }
        }
        .padding(16)
        .appCard()
    }
}

private struct HostOrderRow: View {
    let order: Order
    let onConfirm: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Commande #\(order.id?.prefix(8) ?? "--------")")
                        .font(.cormorantDisplay(18, weight: .semibold))
                        .foregroundStyle(AppColors.charcoal)
                    Text("Portions: \(order.portions)")
                        .font(.labelMedium)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                Text(order.amountCents.asEuro())
                    .font(.dmSans(20, weight: .bold))
                    .foregroundStyle(AppColors.terracotta)
            }

            HStack {
                StatusBadge(type: badgeType(for: order.paymentStatus))
                if order.status != .pending {
                    Text(order.status.displayTitle)
                        .font(.labelMedium)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            if order.status == .pending {
                HStack(spacing: 12) {
                    Button {
                        onConfirm()
                    } label: {
                        Text("Confirmer")
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button {
                        onReject()
                    } label: {
                        Text("Rejeter")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
        .padding(16)
        .appCard()
    }

    private func badgeType(for paymentStatus: PaymentStatus) -> StatusBadge.BadgeType {
        switch paymentStatus {
        case .requires_payment: return .pending
        case .paid: return .completed
        case .failed: return .cancelled
        case .refunded: return .cancelled
        }
    }
}
