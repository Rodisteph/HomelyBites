import SwiftUI

struct HostDashboardView: View {
    @EnvironmentObject private var session: SessionViewModel
    @StateObject private var viewModel = HostDashboardViewModel()

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
                            .background(user.isStripeReady ? Color.green.opacity(0.2) : Color.orange.opacity(0.2), in: Capsule())
                            .foregroundStyle(user.isStripeReady ? .green : .orange)
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
                            .foregroundStyle(.green)
                    }
                }
            }

            Section("Commandes recues") {
                if viewModel.receivedOrders.isEmpty {
                    Text("Aucune commande pour le moment.")
                        .foregroundStyle(.secondary)
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
        }
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
        .sheet(isPresented: $viewModel.showingCreateMeal) {
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
    }
}

private struct HostOrderRow: View {
    let order: Order
    let onConfirm: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Order #\(order.id?.prefix(6) ?? "-")")
                    .font(.headline)
                Spacer()
                Text(order.amountCents.asEuro())
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
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var paymentColor: Color {
        switch order.paymentStatus {
        case .requires_payment:
            return .orange
        case .paid:
            return .green
        case .failed:
            return .red
        case .refunded:
            return .purple
        }
    }
}
