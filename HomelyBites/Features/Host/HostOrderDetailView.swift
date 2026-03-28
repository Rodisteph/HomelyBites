import SwiftUI

struct HostOrderDetailView: View {
    let order: Order
    var onContact: (() -> Void)? = nil
    var onConfirm: (() -> Void)? = nil
    var onReject: (() -> Void)? = nil

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: HBTheme.Spacing.l) {
                Text("Commande hôte")
                    .font(HBTheme.Font.screenTitle)
                    .foregroundStyle(HBTheme.Colors.text)

                CardContainer {
                    Text("Commande #\(order.id?.prefix(8) ?? "--------")")
                        .font(HBTheme.Font.cardTitle)
                        .foregroundStyle(HBTheme.Colors.text)

                    infoRow("Client", value: order.clientId)
                    infoRow("Montant", value: order.amountCents.asEuro())
                    infoRow("Portions", value: "\(order.portions)")
                    infoRow("Statut", value: order.status.displayTitle)
                    infoRow("Paiement", value: order.paymentStatus.displayTitle)
                }

                if !order.note.isEmpty {
                    CardContainer {
                        Text("Note du client")
                            .font(HBTheme.Font.body(16, weight: .semibold))
                            .foregroundStyle(HBTheme.Colors.text)
                        Text(order.note)
                            .font(HBTheme.Font.body(14))
                            .foregroundStyle(HBTheme.Colors.textSecondary)
                    }
                }

                if order.status == .pending {
                    VStack(spacing: HBTheme.Spacing.s) {
                        if let onConfirm {
                            PrimaryButton(title: "Confirmer la commande", icon: "checkmark.circle", action: onConfirm)
                        }
                        if let onReject {
                            SecondaryButton(title: "Rejeter la commande", icon: "xmark.circle", action: onReject)
                        }
                    }
                }

                if let onContact {
                    SecondaryButton(title: "Contacter le client", icon: "message", action: onContact)
                }
            }
            .padding(HBTheme.Spacing.screen)
        }
        .background(HBTheme.Colors.background.ignoresSafeArea())
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(HBTheme.Font.body(14, weight: .medium))
                .foregroundStyle(HBTheme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(HBTheme.Font.body(14, weight: .semibold))
                .foregroundStyle(HBTheme.Colors.text)
        }
    }
}
