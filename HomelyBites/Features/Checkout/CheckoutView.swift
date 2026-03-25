import SwiftUI
import PassKit

struct CheckoutView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CheckoutViewModel
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
            AppColors.cream.ignoresSafeArea()

            if viewModel.paymentSucceeded {
                paymentSuccessView
            } else {
                paymentFormView
            }
        }
        .navigationBarHidden(true)
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

    // MARK: - Payment Form
    private var paymentFormView: some View {
        VStack(spacing: 28) {
            Spacer()

            // Header
            VStack(spacing: 12) {
                BrandLogoView(size: 64)

                Text("Confirmer la commande")
                    .font(.cormorantDisplay(32, weight: .semibold))
                    .foregroundStyle(AppColors.charcoal)

                Text("Commande #\(viewModel.orderId.prefix(8))")
                    .font(.dmSans(13, weight: .medium))
                    .foregroundStyle(AppColors.muted)
            }

            // Order Summary Card
            VStack(spacing: 12) {
                HStack {
                    Text(viewModel.itemLabel)
                        .font(.bodyLarge)
                        .foregroundStyle(AppColors.charcoal)
                    Spacer()
                    Text(viewModel.amountCents.asEuro())
                        .font(.dmSans(20, weight: .bold))
                        .foregroundStyle(AppColors.terracotta)
                }
            }
            .padding(16)
            .appCard()
            .padding(.horizontal, AppMetrics.horizontalPadding)

            // Loading
            if viewModel.isPreparing {
                ProgressView()
                    .tint(AppColors.primary)
                    .scaleEffect(1.2)
            }

            Spacer()

            // Payment Buttons
            VStack(spacing: 16) {
                if PKPaymentAuthorizationController.canMakePayments() {
                    ApplePayButton(
                        amount: viewModel.amountCents,
                        onSuccess: { token in
                            Task {
                                await viewModel.handleApplePayToken(token)
                                if viewModel.paymentSucceeded {
                                    onPaymentCompleted()
                                }
                            }
                        },
                        onError: { error in
                            viewModel.errorMessage = error.localizedDescription
                        }
                    )
                    .frame(height: 52)
                    .padding(.horizontal, AppMetrics.horizontalPadding)
                }

                Button("Annuler") {
                    dismiss()
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.horizontal, AppMetrics.horizontalPadding)
            }
            .padding(.bottom, 36)
        }
    }

    // MARK: - Payment Success
    private var paymentSuccessView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(AppColors.success)

            Text("Paiement réussi !")
                .font(.cormorantDisplay(32, weight: .semibold))
                .foregroundStyle(AppColors.charcoal)

            Text("Votre commande a été confirmée.\nConsultez l'onglet Commandes pour suivre son statut.")
                .font(.bodyMedium)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 8) {
                Text(viewModel.itemLabel)
                    .font(.headlineSmall)
                    .foregroundStyle(AppColors.charcoal)
                Text(viewModel.amountCents.asEuro())
                    .font(.cormorantDisplay(28, weight: .semibold))
                    .foregroundStyle(AppColors.terracotta)
            }
            .padding(20)
            .appCard()
            .padding(.horizontal, AppMetrics.horizontalPadding)

            Spacer()

            Button("Fermer") {
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, AppMetrics.horizontalPadding)
            .padding(.bottom, 36)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.paymentSucceeded)
    }
}
