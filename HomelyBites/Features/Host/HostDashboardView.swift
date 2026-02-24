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
        List {
            if let user = session.appUser {
                Section("Paiements") {
                    HStack {
                        Text("Stripe status")
                        Spacer()
                        Text(user.isStripeReady ? "Onboarded" : "Not ready")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(user.isStripeReady ? AppColors.success.opacity(0.18) : AppColors.warning.opacity(0.18), in: Capsule())
                            .foregroundStyle(user.isStripeReady ? AppColors.success : AppColors.warning)
                    }

                    Button {
                        Task {
                            await viewModel.activatePayments()
                        }
                    } label: {
                        if viewModel.isActivatingPayments {
                            HStack {
                                ProgressView()
                                Text("Ouverture Stripe...")
                            }
                        } else {
                            Text("Activer paiements")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(isLoading: viewModel.isActivatingPayments))

                    Button("Rafraichir profil Stripe") {
                        Task {
                            await session.refreshUserProfile()
                        }
                    }
                }

                Section("Meals") {
                    Button("Creer meal") {
                        viewModel.showingCreateMeal = true
                    }

                    Button("Seed 2 meals de test") {
                        Task {
                            await viewModel.seedMeals(host: user)
                        }
                    }

                    if let successMessage = viewModel.successMessage {
                        Text(successMessage)
                            .font(.footnote)
                            .foregroundStyle(AppColors.success)
                    }

                    if viewModel.hostMeals.isEmpty {
                        Text("Aucun plat publie pour le moment.")
                            .foregroundStyle(AppColors.textSecondary)
                    } else {
                        ForEach(viewModel.hostMeals) { meal in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(meal.title)
                                        .font(.headline)
                                    Spacer()
                                    Text(meal.priceCents.asEuro())
                                        .foregroundStyle(AppColors.primary)
                                }
                                Text("Portions: \(meal.availablePortions)")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                                HStack {
                                    Text(meal.isPublic ? "Public" : "Prive")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(meal.isPublic ? AppColors.success.opacity(0.18) : AppColors.warning.opacity(0.18), in: Capsule())
                                        .foregroundStyle(meal.isPublic ? AppColors.success : AppColors.warning)
                                    Spacer()
                                    Button(meal.isPublic ? "Depublier" : "Publier") {
                                        Task {
                                            await viewModel.toggleMealVisibility(meal: meal)
                                        }
                                    }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                                }
                            }
                            .padding(.vertical, 4)
                            .appCard()
                        }
                        .onDelete { offsets in
                            viewModel.requestMealDeletion(at: offsets)
                        }
                    }
                }
            }

            Section("Commandes recues") {
                if viewModel.receivedOrders.isEmpty {
                    Text("Aucune commande pour le moment.")
                        .foregroundStyle(AppColors.textSecondary)
                } else {
                    ForEach(viewModel.receivedOrders) { order in
                        HostOrderRow(
                            order: order,
                            onConfirm: {
                                let orderId = order.id
                                Task { await viewModel.updateOrderStatus(orderId: orderId, status: .confirmed) }
                            },
                            onReject: {
                                let orderId = order.id
                                Task { await viewModel.updateOrderStatus(orderId: orderId, status: .rejected) }
                            }
                        )
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle("Host Dashboard")
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
            Text("Le plat \"\(meal.title)\" sera supprime definitivement.")
        }
    }
}

private struct HostOrderRow: View {
    let order: Order
    let onConfirm: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Order #\(order.id.prefix(6))")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text(order.amountCents.asEuro())
                    .foregroundStyle(AppColors.primary)
            }

            Text("Payment: \(order.paymentStatus.displayTitle)")
                .font(.subheadline)
                .foregroundStyle(paymentColor)

            if order.status == .pending {
                HStack {
                    Button("Confirmer") {
                        onConfirm()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Rejeter", role: .destructive) {
                        onReject()
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Text("Status: \(order.status.displayTitle)")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(.vertical, 4)
        .appCard()
    }

    private var paymentColor: Color {
        switch order.paymentStatus {
        case .requires_payment:
            return AppColors.warning
        case .paid:
            return AppColors.success
        case .failed:
            return AppColors.danger
        case .refunded:
            return .purple
        }
    }
}
