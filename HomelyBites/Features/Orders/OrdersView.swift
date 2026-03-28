import SwiftUI

struct OrdersView: View {
    @EnvironmentObject private var session: SessionViewModel
    @StateObject private var viewModel = OrdersViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: HBTheme.Spacing.m) {
                if viewModel.orders.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bag")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(HBTheme.Colors.textSecondary.opacity(0.5))
                        Text("Aucune commande")
                            .font(HBTheme.Font.title(22))
                            .foregroundStyle(HBTheme.Colors.text)
                        Text("Tes commandes apparaitront ici apres paiement.")
                            .font(HBTheme.Font.body(14))
                            .foregroundStyle(HBTheme.Colors.textSecondary)
                    }
                    .padding(.top, 80)
                } else {
                    ForEach(viewModel.orders) { order in
                        OrderRow(order: order)
                    }
                }
            }
            .padding(.horizontal, HBTheme.Spacing.screen)
            .padding(.vertical, HBTheme.Spacing.m)
        }
        .hbBackground()
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
