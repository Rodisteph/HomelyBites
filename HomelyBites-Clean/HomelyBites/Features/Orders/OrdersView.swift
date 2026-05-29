import SwiftUI

struct OrdersView: View {
    @Environment(SessionViewModel.self) private var session
    @State private var viewModel = OrdersViewModel()

    var body: some View {
        List {
            if viewModel.orders.isEmpty {
                ContentUnavailableView(
                    "Aucune commande",
                    systemImage: "cart.badge.questionmark",
                    description: Text("Vos commandes apparaîtront ici après paiement.")
                )
            } else {
                ForEach(viewModel.orders) { order in
                    OrderRowView(order: order)
                }
            }
        }
        .navigationTitle("Mes commandes")
        .task {
            guard let uid = session.appUser?.id else { return }
            viewModel.startListening(clientId: uid)
            if viewModel.orders.isEmpty { await viewModel.refresh(clientId: uid) }
        }
        .refreshable {
            guard let uid = session.appUser?.id else { return }
            await viewModel.refresh(clientId: uid)
        }
        .errorAlert(message: $viewModel.errorMessage)
    }
}

// MARK: - Sous-composant (privé à ce fichier)

private struct OrderRowView: View {
    let order: Order

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Order #\(order.id.prefix(6))").font(.headline)
                Spacer()
                Text(order.amountCents.asEuro()).font(.subheadline.weight(.semibold))
            }
            HStack {
                Text("Status : \(order.status.displayTitle)")
                Spacer()
                paymentBadge
            }
            .font(.subheadline)
            Text("Portions : \(order.portions)").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var paymentBadge: some View {
        Text(order.paymentStatus.displayTitle)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(paymentColor.opacity(0.2), in: Capsule())
            .foregroundStyle(paymentColor)
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
