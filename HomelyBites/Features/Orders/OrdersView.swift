import SwiftUI

struct OrdersView: View {
    @EnvironmentObject private var session: SessionViewModel
    @StateObject private var viewModel = OrdersViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.orders.isEmpty {
                    ContentUnavailableView(
                        "Aucune commande",
                        systemImage: "cart.badge.questionmark",
                        description: Text("Vos commandes apparaîtront ici après paiement.")
                    )
                    .padding(.top, 100)
                } else {
                    ForEach(viewModel.orders) { order in
                        OrderRowView(order: order)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 16)
        }
        .background(AppColors.cream)
        .navigationTitle("Mes commandes")
        .task {
            guard let uid = session.appUser?.id else { return }
            viewModel.startListening(clientId: uid)

            if viewModel.orders.isEmpty {
                await viewModel.refresh(clientId: uid)
            }
        }
        .refreshable {
            guard let uid = session.appUser?.id else { return }
            await viewModel.refresh(clientId: uid)
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
    }
}

private struct OrderRowView: View {
    let order: Order

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Order ID & Price
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Commande #\(order.id?.prefix(8) ?? "--------")")
                        .font(.cormorantDisplay(20, weight: .semibold))
                        .foregroundStyle(AppColors.charcoal)
                    Text("Portions: \(order.portions)")
                        .font(.labelMedium)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                Text(order.amountCents.asEuro())
                    .font(.dmSans(22, weight: .bold))
                    .foregroundStyle(AppColors.terracotta)
            }

            Divider()

            // Status Row
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Statut de la commande")
                        .font(.labelMedium)
                        .foregroundStyle(AppColors.textSecondary)
                    Text(order.status.displayTitle)
                        .font(.dmSans(15, weight: .semibold))
                        .foregroundStyle(statusColor)
                }

                Spacer()

                paymentBadge
            }
        }
        .padding(16)
        .appCard()
    }

    private var paymentBadge: some View {
        Text(order.paymentStatus.displayTitle)
            .font(.labelMedium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(colorForPayment.opacity(0.2), in: Capsule())
            .foregroundStyle(colorForPayment)
    }

    private var statusColor: Color {
        switch order.status {
        case .pending: return AppColors.warning
        case .confirmed: return Color(hex: "4A90E2")
        case .cancelled: return AppColors.textSecondary
        case .rejected: return AppColors.danger
        }
    }

    private var colorForPayment: Color {
        switch order.paymentStatus {
        case .requires_payment: return AppColors.warning
        case .paid: return AppColors.success
        case .failed: return AppColors.danger
        case .refunded: return .purple
        }
    }
}
