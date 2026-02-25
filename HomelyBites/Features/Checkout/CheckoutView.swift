import SwiftUI
import StripePaymentSheet
import PassKit

struct CheckoutView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CheckoutViewModel
    @State private var paymentSheet: PaymentSheet?
    @State private var showPayment = false
    @State private var uiState: CheckoutUIState = .idle

    private let clientSecret: String
    let onPaymentCompleted: () -> Void

    init(
        orderId: String,
        clientSecret: String,
        onPaymentCompleted: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: CheckoutViewModel(
                orderId: orderId,
                clientSecret: clientSecret
            )
        )
        self.clientSecret = clientSecret
        self.onPaymentCompleted = onPaymentCompleted
    }

    var body: some View {
        let content =
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        BrandLogoView(size: 60)
                        Text("Paiement sécurisé")
                            .font(.cormorantDisplay(28, weight: .semibold))
                            .foregroundStyle(AppColors.charcoal)
                        Text("Commande #\(viewModel.orderId.prefix(8))")
                            .font(.labelMedium)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(.top, 20)

                    // Loading State
                    if uiState == .loading {
                        ProgressView("Préparation du paiement...")
                            .tint(AppColors.terracotta)
                    }

                    // Status Message
                    if let status = statusMessage {
                        HStack(spacing: 12) {
                            Image(systemName: statusIcon)
                                .font(.system(size: 20))
                            Text(status)
                                .font(.bodyMedium)
                        }
                        .foregroundStyle(statusColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(statusColor.opacity(0.1))
                        )
                    }

                    // Payment Buttons
                    VStack(spacing: 16) {
                        if StripeService.isApplePayAvailable {
                            ApplePayBuyButton {
                                presentPaymentSheet()
                            }
                            .frame(height: 52)
                            .disabled(uiState == .loading || paymentSheet == nil)

                            HStack(spacing: 12) {
                                Rectangle()
                                    .fill(AppColors.textSecondary.opacity(0.3))
                                    .frame(height: 1)
                                Text("ou")
                                    .font(.labelMedium)
                                    .foregroundStyle(AppColors.textSecondary)
                                Rectangle()
                                    .fill(AppColors.textSecondary.opacity(0.3))
                                    .frame(height: 1)
                            }
                        }

                        Button {
                            presentPaymentSheet()
                        } label: {
                            HStack {
                                Image(systemName: "creditcard.fill")
                                Text("Payer par carte")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(uiState == .loading || paymentSheet == nil)

                        Button("Annuler") {
                            dismiss()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
            .background(AppColors.cream)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
            .task {
                preparePaymentSheetIfNeeded()
            }
        }
        .alert(
            "Erreur paiement",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            ),
            actions: { Button("OK", role: .cancel) {} },
            message: { Text(viewModel.errorMessage ?? "") }
        )

        if let sheet = paymentSheet {
            content
                .paymentSheet(
                    isPresented: $showPayment,
                    paymentSheet: sheet
                ) { result in
                    handlePaymentResult(result)
                }
        } else {
            content
        }
    }

    private var statusMessage: String? {
        switch uiState {
        case .idle:
            return viewModel.statusMessage
        case .loading:
            return "Ouverture du formulaire de paiement..."
        case .result(let message):
            return message
        }
    }

    private var statusIcon: String {
        switch uiState {
        case .idle, .loading:
            return "info.circle.fill"
        case .result(let message):
            if message.contains("confirmé") {
                return "checkmark.circle.fill"
            } else if message.contains("annulé") {
                return "xmark.circle.fill"
            } else {
                return "exclamationmark.triangle.fill"
            }
        }
    }

    private var statusColor: Color {
        switch uiState {
        case .idle:
            return AppColors.textSecondary
        case .loading:
            return AppColors.terracotta
        case .result(let message):
            if message.contains("confirmé") {
                return AppColors.success
            } else if message.contains("annulé") {
                return AppColors.warning
            } else {
                return AppColors.danger
            }
        }
    }

    private func preparePaymentSheetIfNeeded() {
        guard paymentSheet == nil else { return }
        let trimmedClientSecret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedClientSecret.isEmpty else {
            viewModel.errorMessage = "Client secret Stripe manquant."
            return
        }

        uiState = .loading
        paymentSheet = StripeService.makePaymentSheet(paymentIntentClientSecret: trimmedClientSecret)
        uiState = .idle
    }

    private func presentPaymentSheet() {
        if paymentSheet == nil {
            preparePaymentSheetIfNeeded()
        }
        guard paymentSheet != nil else { return }
        showPayment = true
        uiState = .loading
    }

    private func handlePaymentResult(_ result: PaymentSheetResult) {
        viewModel.handlePaymentResult(result)

        switch result {
        case .completed:
            uiState = .result("Paiement confirmé.")
            onPaymentCompleted()
            dismiss()
        case .canceled:
            uiState = .result("Paiement annulé.")
        case .failed(let error):
            viewModel.errorMessage = error.localizedDescription
            uiState = .result("Paiement échoué.")
        }
    }
}

private enum CheckoutUIState: Equatable {
    case idle
    case loading
    case result(String)
}

private struct ApplePayBuyButton: UIViewRepresentable {
    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeUIView(context: Context) -> PKPaymentButton {
        let button = PKPaymentButton(paymentButtonType: .buy, paymentButtonStyle: .black)
        button.addTarget(context.coordinator, action: #selector(Coordinator.didTap), for: .touchUpInside)
        button.layer.cornerRadius = 12
        button.clipsToBounds = true
        return button
    }

    func updateUIView(_ uiView: PKPaymentButton, context: Context) {}

    final class Coordinator: NSObject {
        private let action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func didTap() {
            action()
        }
    }
}
