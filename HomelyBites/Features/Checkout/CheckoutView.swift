import SwiftUI
import StripePaymentSheet

struct CheckoutView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CheckoutViewModel
    @State private var hasCompleted = false
    let onPaymentCompleted: () -> Void

    init(
        orderId: String,
        amountCents: Int,
        itemLabel: String,
        onPaymentCompleted: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: CheckoutViewModel(
                orderId: orderId,
                amountCents: amountCents,
                itemLabel: itemLabel
            )
        )
        self.onPaymentCompleted = onPaymentCompleted
    }

    var body: some View {
        ZStack {
            HBTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 10) {
                    BrandLogoView(size: 62)
                    Text("Confirmer le paiement")
                        .font(HBTheme.Font.display(30))
                        .foregroundStyle(HBTheme.Colors.text)
                    Text("Commande #\(viewModel.orderId.prefix(8))")
                        .font(HBTheme.Font.label())
                        .foregroundStyle(HBTheme.Colors.textSecondary)
                }

                VStack(spacing: 8) {
                    Text(viewModel.itemLabel)
                        .font(HBTheme.Font.body(16, weight: .semibold))
                        .foregroundStyle(HBTheme.Colors.text)
                        .multilineTextAlignment(.center)
                    Text(viewModel.amountCents.asEuro())
                        .font(HBTheme.Font.display(36))
                        .foregroundStyle(HBTheme.Colors.primary)
                }

                if viewModel.isPreparing {
                    ProgressView()
                        .tint(HBTheme.Colors.primary)
                }

                if let message = viewModel.statusMessage {
                    HStack(spacing: 10) {
                        Image(systemName: "clock.badge.checkmark")
                            .foregroundStyle(HBTheme.Colors.info)
                        Text(message)
                            .font(HBTheme.Font.body(14, weight: .medium))
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: HBTheme.Radius.button, style: .continuous)
                            .fill(HBTheme.Colors.info.opacity(0.12))
                    )
                    .padding(.horizontal, HBTheme.Spacing.screen)
                }

                Spacer()

                VStack(spacing: 14) {
                    PrimaryButton(
                        title: "Payer maintenant",
                        icon: "creditcard.fill",
                        isLoading: viewModel.isPreparing,
                        isDisabled: viewModel.isPreparing || viewModel.paymentSucceeded || viewModel.isAwaitingConfirmation
                    ) {
                        Task { await viewModel.preparePaymentSheet() }
                    }
                    .padding(.horizontal, HBTheme.Spacing.screen)

                    SecondaryButton(title: "Annuler") {
                        dismiss()
                    }
                    .disabled(viewModel.isPreparing || viewModel.isAwaitingConfirmation)
                    .padding(.horizontal, HBTheme.Spacing.screen)
                }
                .padding(.bottom, 32)
            }
        }
        .navigationBarHidden(true)
        .overlay {
            if let paymentSheet = viewModel.paymentSheet {
                Color.clear
                    .frame(width: 0, height: 0)
                    .paymentSheet(
                        isPresented: $viewModel.showPaymentSheet,
                        paymentSheet: paymentSheet,
                        onCompletion: viewModel.handlePaymentSheetResult
                    )
            }
        }
        .onChange(of: viewModel.paymentSucceeded) { _, succeeded in
            guard succeeded, !hasCompleted else { return }
            hasCompleted = true
            onPaymentCompleted()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { dismiss() }
        }
        .alert(
            "Erreur de paiement",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            ),
            actions: { Button("OK", role: .cancel) {} },
            message: { Text(viewModel.errorMessage ?? "") }
        )
    }
}
