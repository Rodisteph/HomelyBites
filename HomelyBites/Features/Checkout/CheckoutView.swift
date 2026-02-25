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

            VStack(spacing: 28) {
                Spacer()

                // Header
                VStack(spacing: 12) {
                    BrandLogoView(size: 64)

                    Text("Confirm Order")
                        .font(.cormorantDisplay(32, weight: .semibold))
                        .foregroundStyle(AppColors.charcoal)

                    Text("Order #\(viewModel.orderId.prefix(8))")
                        .font(.dmSans(13, weight: .medium))
                        .foregroundStyle(AppColors.muted)
                }

                // Loading
                if viewModel.isPreparing {
                    ProgressView()
                        .tint(AppColors.primary)
                        .scaleEffect(1.2)
                }

                // Status Message
                if let msg = viewModel.statusMessage {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                        Text(msg)
                            .font(.dmSans(14, weight: .medium))
                    }
                    .foregroundStyle(AppColors.success)
                    .multilineTextAlignment(.center)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.success.opacity(0.1))
                    )
                    .padding(.horizontal, AppMetrics.horizontalPadding)
                }

                Spacer()

                // Apple Pay Button
                VStack(spacing: 16) {
                    ApplePayButton(
                        amount: viewModel.amountCents,
                        onSuccess: { token in
                            Task {
                                await viewModel.handleApplePayToken(token)
                                if viewModel.paymentSucceeded {
                                    onPaymentCompleted()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        dismiss()
                                    }
                                }
                            }
                        },
                        onError: { error in
                            viewModel.errorMessage = error.localizedDescription
                        }
                    )
                    .frame(height: 52)
                    .padding(.horizontal, AppMetrics.horizontalPadding)

                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.horizontal, AppMetrics.horizontalPadding)
                }
                .padding(.bottom, 36)
            }
        }
        .navigationBarHidden(true)
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
