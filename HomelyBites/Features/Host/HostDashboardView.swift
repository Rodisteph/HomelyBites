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
            VStack(alignment: .leading, spacing: HBMetrics.Spacing.l) {
                if let user = session.appUser {
                    welcomeHeader(for: user)
                    statsStrip
                    if pendingOrdersCount > 0 {
                        newOrdersAlert
                    }
                    stripeStatusCard(for: user)
                    mealsSection(for: user)
                    ordersSection
                }
            }
            .padding(.horizontal, HBMetrics.horizontalPadding)
            .padding(.vertical, HBMetrics.Spacing.m)
        }
        .hbBackground()
        .hbNavTitle("Host Dashboard", displayMode: .inline)
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
        ) { _ in
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

    @ViewBuilder
    private func welcomeHeader(for user: AppUser) -> some View {
        VStack(alignment: .leading, spacing: HBMetrics.Spacing.xs) {
            Text("Bienvenue, \(user.fullName)")
                .font(HBTypography.display(size: 34))
                .foregroundStyle(HBColors.textPrimary)
            Text("Pilotez vos repas, commandes et paiements")
                .font(HBTypography.body(size: 15))
                .foregroundStyle(HBColors.textSecondary)
        }
    }

    private var statsStrip: some View {
        HStack(spacing: HBMetrics.Spacing.s) {
            statCard(title: "Repas", value: "\(viewModel.hostMeals.count)", tint: HBColors.sage)
            statCard(title: "Commandes", value: "\(viewModel.receivedOrders.count)", tint: HBColors.terracotta)
            statCard(title: "CA payé", value: paidRevenueCents.asEuro(), tint: HBColors.terracottaDark)
        }
    }

    private var newOrdersAlert: some View {
        HStack(alignment: .center, spacing: HBMetrics.Spacing.s) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 3) {
                Text("Nouvelles commandes")
                    .font(HBTypography.body(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(pendingOrdersCount) commande(s) en attente de validation")
                    .font(HBTypography.label(size: 12))
                    .foregroundStyle(.white.opacity(0.9))
            }

            Spacer()
        }
        .padding(HBMetrics.cardPadding)
        .background(
            LinearGradient(
                colors: [HBColors.terracottaDark, HBColors.terracotta],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: HBMetrics.Radius.card, style: .continuous))
        .hbShadow(.strong)
    }

    @ViewBuilder
    private func stripeStatusCard(for user: AppUser) -> some View {
        CardContainer {
            Text("Paiements")
                .hbTitle()

                HStack {
                    VStack(alignment: .leading, spacing: HBMetrics.Spacing.xs) {
                        Text("Stripe status")
                            .font(HBTypography.label())
                            .foregroundStyle(HBColors.textSecondary)
                        Text(user.isStripeReady ? "Activé" : "Non activé")
                            .font(HBTypography.body(size: 16, weight: .semibold))
                            .foregroundStyle(user.isStripeReady ? HBColors.success : HBColors.warning)

                        Text("Onboarding: \(user.stripeOnboarded == true ? "Terminé" : "En attente")")
                            .font(HBTypography.label(size: 12))
                            .foregroundStyle(HBColors.textSecondary)

                        Text("Statut: \(user.stripeStatusDisplay)")
                            .font(HBTypography.label(size: 12))
                            .foregroundStyle(HBColors.textSecondary)
                    }
                    Spacer()
                    Badge(label: user.isStripeReady ? "Prêt" : "Action requise", kind: user.isStripeReady ? .success : .warning)
                }

            PrimaryButton(
                title: viewModel.isActivatingPayments ? "Ouverture Stripe..." : "Activer paiements",
                icon: "creditcard.fill",
                isLoading: viewModel.isActivatingPayments,
                isDisabled: viewModel.isActivatingPayments
            ) {
                Task {
                    await viewModel.activatePayments()
                }
            }

            SecondaryButton(title: "Rafraîchir profil Stripe", icon: "arrow.clockwise") {
                Task {
                    await viewModel.refreshStripeStatus()
                    await session.refreshUserProfile()
                }
            }
        }
    }

    @ViewBuilder
    private func mealsSection(for user: AppUser) -> some View {
        VStack(alignment: .leading, spacing: HBMetrics.Spacing.m) {
            HStack {
                Text("Mes plats")
                    .font(HBTypography.title(size: 28))
                    .foregroundStyle(HBColors.textPrimary)
                Spacer()
                Button {
                    viewModel.showingCreateMeal = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(HBColors.terracotta)
                }
            }

            if let successMessage = viewModel.successMessage {
                CardContainer {
                    HStack(spacing: HBMetrics.Spacing.s) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(HBColors.success)
                        Text(successMessage)
                            .font(HBTypography.body(size: 14))
                            .foregroundStyle(HBColors.success)
                    }
                }
            }

            SecondaryButton(
                title: viewModel.isBackfillingLocations ? "Mise à jour des localisations..." : "Ajouter localisation aux repas existants",
                icon: "location.fill",
                isDisabled: viewModel.isBackfillingLocations
            ) {
                Task {
                    await viewModel.backfillMealLocationsForHost()
                }
            }

            if viewModel.hostMeals.isEmpty {
                CardContainer {
                    Text("Aucun plat publié pour le moment.")
                        .font(HBTypography.body(size: 15))
                        .foregroundStyle(HBColors.textSecondary)

                    SecondaryButton(title: "Seed 2 meals de test", icon: "fork.knife") {
                        Task {
                            await viewModel.seedMeals(host: user)
                        }
                    }
                }
            } else {
                LazyVStack(spacing: HBMetrics.Spacing.m) {
                    ForEach(Array(viewModel.hostMeals.enumerated()), id: \.element.id) { index, meal in
                        CardContainer {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: HBMetrics.Spacing.xs) {
                                    Text(meal.title)
                                        .font(HBTypography.title(size: 22))
                                        .foregroundStyle(HBColors.textPrimary)
                                    Text("Portions disponibles: \(meal.availablePortions)")
                                        .font(HBTypography.label())
                                        .foregroundStyle(HBColors.textSecondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: HBMetrics.Spacing.s) {
                                    Text(meal.priceCents.asEuro())
                                        .font(HBTypography.body(size: 18, weight: .bold))
                                        .foregroundStyle(HBColors.terracotta)

                                    Button(role: .destructive) {
                                        viewModel.requestMealDeletion(at: IndexSet(integer: index))
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .font(.system(size: 14, weight: .semibold))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var ordersSection: some View {
        VStack(alignment: .leading, spacing: HBMetrics.Spacing.m) {
            Text("Commandes reçues")
                .font(HBTypography.title(size: 28))
                .foregroundStyle(HBColors.textPrimary)

            if viewModel.receivedOrders.isEmpty {
                CardContainer {
                    Text("Aucune commande pour le moment.")
                        .font(HBTypography.body(size: 15))
                        .foregroundStyle(HBColors.textSecondary)
                }
            } else {
                LazyVStack(spacing: HBMetrics.Spacing.m) {
                    ForEach(viewModel.receivedOrders) { order in
                        OrderRow(
                            order: order,
                            onConfirm: {
                                guard let orderId = order.id else { return }
                                Task {
                                    await viewModel.updateOrderStatus(orderId: orderId, status: .confirmed)
                                }
                            },
                            onReject: {
                                guard let orderId = order.id else { return }
                                Task {
                                    await viewModel.updateOrderStatus(orderId: orderId, status: .rejected)
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    private func statCard(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: HBMetrics.Spacing.xs) {
            Text(title)
                .font(HBTypography.label(size: 12))
                .foregroundStyle(HBColors.textSecondary)
            Text(value)
                .font(HBTypography.title(size: 20))
                .foregroundStyle(HBColors.textPrimary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.24), lineWidth: 1)
        )
    }

    private var pendingOrdersCount: Int {
        viewModel.receivedOrders.filter { $0.status == .pending }.count
    }

    private var paidRevenueCents: Int {
        viewModel.receivedOrders
            .filter { $0.paymentStatus == .paid }
            .reduce(0) { partialResult, order in
                partialResult + order.amountCents
            }
    }
}
