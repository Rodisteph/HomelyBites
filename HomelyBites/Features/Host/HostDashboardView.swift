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
            VStack(alignment: .leading, spacing: HBTheme.Spacing.l) {
                if let user = session.appUser {
                    welcomeHeader(for: user)
                    statsStrip
                    if pendingOrdersCount > 0 { newOrdersAlert }
                    stripeStatusCard(for: user)
                    mealsSection(for: user)
                    ordersSection
                }
            }
            .padding(.horizontal, HBTheme.Spacing.screen)
            .padding(.vertical, HBTheme.Spacing.m)
        }
        .hbBackground()
        .hbNavTitle("Dashboard", displayMode: .inline)
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
                Task { await viewModel.refresh(hostId: hostId) }
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
            actions: { Button("OK", role: .cancel) {} },
            message: { Text(viewModel.errorMessage ?? "") }
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
                Task { await viewModel.confirmMealDeletion(hostId: hostId) }
            }
            .disabled(viewModel.isDeletingMeal)
        } message: { meal in
            Text("Le plat \"\(meal.title)\" sera supprime definitivement.")
        }
    }

    // MARK: - Welcome

    @ViewBuilder
    private func welcomeHeader(for user: AppUser) -> some View {
        VStack(alignment: .leading, spacing: HBTheme.Spacing.xs) {
            Text("Bienvenue, \(user.fullName)")
                .font(HBTheme.Font.display(34))
                .foregroundStyle(HBTheme.Colors.text)
            Text("Pilotez vos repas, commandes et paiements")
                .font(HBTheme.Font.body(15))
                .foregroundStyle(HBTheme.Colors.textSecondary)
        }
    }

    // MARK: - Stats

    private var statsStrip: some View {
        HStack(spacing: HBTheme.Spacing.s) {
            statCard(title: "Repas", value: "\(viewModel.hostMeals.count)", tint: HBTheme.Colors.sage)
            statCard(title: "Commandes", value: "\(viewModel.receivedOrders.count)", tint: HBTheme.Colors.primary)
            statCard(title: "CA paye", value: paidRevenueCents.asEuro(), tint: HBTheme.Colors.primaryDark)
        }
    }

    private var newOrdersAlert: some View {
        HStack(alignment: .center, spacing: HBTheme.Spacing.s) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 3) {
                Text("Nouvelles commandes")
                    .font(HBTheme.Font.body(15, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(pendingOrdersCount) commande(s) en attente")
                    .font(HBTheme.Font.label(12))
                    .foregroundStyle(.white.opacity(0.9))
            }
            Spacer()
        }
        .padding(HBTheme.Spacing.m)
        .background(
            LinearGradient(
                colors: [HBTheme.Colors.primaryDark, HBTheme.Colors.primary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: HBTheme.Radius.card, style: .continuous))
        .hbShadow(.strong)
    }

    // MARK: - Stripe

    @ViewBuilder
    private func stripeStatusCard(for user: AppUser) -> some View {
        CardContainer {
            Text("Paiements").hbTitle()

            HStack {
                VStack(alignment: .leading, spacing: HBTheme.Spacing.xs) {
                    Text("Stripe")
                        .font(HBTheme.Font.label())
                        .foregroundStyle(HBTheme.Colors.textSecondary)
                    Text(user.isStripeReady ? "Active" : "Non active")
                        .font(HBTheme.Font.body(16, weight: .semibold))
                        .foregroundStyle(user.isStripeReady ? HBTheme.Colors.success : HBTheme.Colors.warning)
                }
                Spacer()
                Badge(label: user.isStripeReady ? "Pret" : "Action requise", kind: user.isStripeReady ? .success : .warning)
            }

            PrimaryButton(
                title: viewModel.isActivatingPayments ? "Ouverture Stripe..." : "Activer paiements",
                icon: "creditcard.fill",
                isLoading: viewModel.isActivatingPayments,
                isDisabled: viewModel.isActivatingPayments
            ) {
                Task { await viewModel.activatePayments() }
            }

            SecondaryButton(title: "Rafraichir profil Stripe", icon: "arrow.clockwise") {
                Task {
                    await viewModel.refreshStripeStatus()
                    await session.refreshUserProfile()
                }
            }
        }
    }

    // MARK: - Meals

    @ViewBuilder
    private func mealsSection(for user: AppUser) -> some View {
        VStack(alignment: .leading, spacing: HBTheme.Spacing.m) {
            HStack {
                Text("Mes plats")
                    .font(HBTheme.Font.sectionTitle)
                    .foregroundStyle(HBTheme.Colors.text)
                Spacer()
                Button { viewModel.showingCreateMeal = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(HBTheme.Colors.primary)
                }
            }

            if let successMessage = viewModel.successMessage {
                CardContainer {
                    HStack(spacing: HBTheme.Spacing.s) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(HBTheme.Colors.success)
                        Text(successMessage)
                            .font(HBTheme.Font.body(14))
                            .foregroundStyle(HBTheme.Colors.success)
                    }
                }
            }

            if viewModel.hostMeals.isEmpty {
                CardContainer {
                    Text("Aucun plat publie pour le moment.")
                        .font(HBTheme.Font.body(15))
                        .foregroundStyle(HBTheme.Colors.textSecondary)
                }
            } else {
                LazyVStack(spacing: HBTheme.Spacing.m) {
                    ForEach(Array(viewModel.hostMeals.enumerated()), id: \.element.id) { index, meal in
                        CardContainer {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: HBTheme.Spacing.xs) {
                                    Text(meal.title)
                                        .font(HBTheme.Font.cardTitle)
                                        .foregroundStyle(HBTheme.Colors.text)
                                    Text("Portions : \(meal.availablePortions)")
                                        .font(HBTheme.Font.label())
                                        .foregroundStyle(HBTheme.Colors.textSecondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: HBTheme.Spacing.s) {
                                    Text(meal.priceCents.asEuro())
                                        .font(HBTheme.Font.body(18, weight: .bold))
                                        .foregroundStyle(HBTheme.Colors.primary)
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

    // MARK: - Orders

    @ViewBuilder
    private var ordersSection: some View {
        VStack(alignment: .leading, spacing: HBTheme.Spacing.m) {
            Text("Commandes recues")
                .font(HBTheme.Font.sectionTitle)
                .foregroundStyle(HBTheme.Colors.text)

            if viewModel.receivedOrders.isEmpty {
                CardContainer {
                    Text("Aucune commande pour le moment.")
                        .font(HBTheme.Font.body(15))
                        .foregroundStyle(HBTheme.Colors.textSecondary)
                }
            } else {
                LazyVStack(spacing: HBTheme.Spacing.m) {
                    ForEach(viewModel.receivedOrders) { order in
                        OrderRow(
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
        }
    }

    // MARK: - Helpers

    private func statCard(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: HBTheme.Spacing.xs) {
            Text(title)
                .font(HBTheme.Font.label(12))
                .foregroundStyle(HBTheme.Colors.textSecondary)
            Text(value)
                .font(HBTheme.Font.title(20))
                .foregroundStyle(HBTheme.Colors.text)
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
            .reduce(0) { $0 + $1.amountCents }
    }
}
