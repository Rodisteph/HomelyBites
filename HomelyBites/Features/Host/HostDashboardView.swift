import SwiftUI

struct HostDashboardView: View {
    @Environment(SessionViewModel.self) private var session
    @State private var viewModel = HostDashboardViewModel()

    var body: some View {
        List {
            if let user = session.appUser {
                Section("Paiements") {
                    stripeStatusRow(user: user)
                    activatePaymentsButton
                    Button("Rafraichir profil Stripe") {
                        Task { await session.refreshUserProfile() }
                    }
                }

                Section("Repas") {
                    Button("Creer un repas") { viewModel.showingCreateMeal = true }
                    Button("Seed 2 repas de test") {
                        Task { await viewModel.seedMeals(host: user) }
                    }
                    if let msg = viewModel.successMessage {
                        Text(msg).font(.footnote).foregroundStyle(.green)
                    }
                }
            }

            Section("Commandes recues") {
                if viewModel.receivedOrders.isEmpty {
                    Text("Aucune commande pour le moment.").foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.receivedOrders) { order in
                        HostOrderRow(order: order,
                            onConfirm: { Task { await viewModel.updateOrderStatus(orderId: order.id, status: .confirmed) } },
                            onReject:  { Task { await viewModel.updateOrderStatus(orderId: order.id, status: .rejected) } }
                        )
                    }
                }
            }
        }
        .navigationTitle("Host Dashboard")
        .task {
            guard let hostId = session.appUser?.id else { return }
            viewModel.startListening(hostId: hostId)
            if viewModel.receivedOrders.isEmpty { await viewModel.refresh(hostId: hostId) }
        }
        .refreshable {
            guard let hostId = session.appUser?.id else { return }
            await viewModel.refresh(hostId: hostId)
            await session.refreshUserProfile()
        }
        .sheet(isPresented: $viewModel.showingCreateMeal) {
            if let user = session.appUser { CreateMealView(host: user) }
        }
        .sheet(isPresented: Binding(
            get:  { viewModel.onboardingURL != nil },
            set:  { if !$0 { viewModel.onboardingURL = nil } }
        )) {
            if let url = viewModel.onboardingURL { SafariView(url: url) }
        }
        .errorAlert(message: $viewModel.errorMessage)
    }

    private func stripeStatusRow(user: AppUser) -> some View {
        HStack {
            Text("Stripe status")
            Spacer()
            Text(user.isStripeReady ? "Onboarde" : "Non pret")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(user.isStripeReady ? Color.green.opacity(0.2) : Color.orange.opacity(0.2), in: Capsule())
                .foregroundStyle(user.isStripeReady ? .green : .orange)
        }
    }

    private var activatePaymentsButton: some View {
        Button {
            Task { await viewModel.activatePayments() }
        } label: {
            if viewModel.isActivatingPayments {
                HStack { ProgressView(); Text("Ouverture Stripe...") }
            } else {
                Text("Activer paiements")
            }
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
                Text("Commande #\(order.id.prefix(6))").font(.headline)
                Spacer()
                Text(order.amountCents.asEuro())
            }
            Text("Paiement : \(order.paymentStatus.displayTitle)")
                .font(.subheadline).foregroundStyle(paymentColor)

            if order.status == .pending {
                HStack {
                    Button("Confirmer", action: onConfirm).buttonStyle(.borderedProminent)
                    Button("Rejeter", role: .destructive, action: onReject).buttonStyle(.bordered)
                }
            } else {
                Text("Statut : \(order.status.displayTitle)").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var paymentColor: Color {
        switch order.paymentStatus {
        case .requires_payment: return .orange
        case .paid:             return .green
        case .failed:           return .red
        case .refunded:         return .purple
        }
    }
}
