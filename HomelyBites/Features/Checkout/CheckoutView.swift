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
            AppColors.cream.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 10) {
                    BrandLogoView(size: 62)
                    Text("Confirmer le paiement")
                        .font(.cormorantDisplay(30, weight: .semibold))
                        .foregroundStyle(AppColors.charcoal)
                    Text("Order #\(viewModel.orderId.prefix(8))")
                        .font(.dmSans(13, weight: .medium))
                        .foregroundStyle(AppColors.muted)
                }

                VStack(spacing: 8) {
                    Text(viewModel.itemLabel)
                        .font(.dmSans(16, weight: .semibold))
                        .foregroundStyle(AppColors.charcoal)
                        .multilineTextAlignment(.center)
                    Text(viewModel.amountCents.asEuro())
                        .font(.cormorantDisplay(36, weight: .semibold))
                        .foregroundStyle(AppColors.primary)
                }

                if viewModel.isPreparing {
                    ProgressView()
                        .tint(AppColors.primary)
                }

                if let message = viewModel.statusMessage {
                    HStack(spacing: 10) {
                        Image(systemName: "clock.badge.checkmark")
                            .foregroundStyle(AppColors.info)
                        Text(message)
                            .font(.dmSans(14, weight: .medium))
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppColors.info.opacity(0.12))
                    )
                    .padding(.horizontal, AppMetrics.horizontalPadding)
                }

                Spacer()

                VStack(spacing: 14) {
                    PrimaryButton(
                        title: "Payer maintenant",
                        icon: "creditcard.fill",
                        isLoading: viewModel.isPreparing,
                        isDisabled: viewModel.isPreparing || viewModel.paymentSucceeded || viewModel.isAwaitingConfirmation
                    ) {
                        Task {
                            await viewModel.preparePaymentSheet()
                        }
                    }
                    .padding(.horizontal, AppMetrics.horizontalPadding)

                    Button("Annuler") {
                        dismiss()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(viewModel.isPreparing || viewModel.isAwaitingConfirmation)
                    .padding(.horizontal, AppMetrics.horizontalPadding)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                dismiss()
            }
        }
        .alert(
            "Payment Error",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            ),
            actions: { Button("OK", role: .cancel) {} },
            message: { Text(viewModel.errorMessage ?? "") }
        )
    }
}
