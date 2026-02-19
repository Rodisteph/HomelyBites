import SwiftUI
import StripePaymentSheet

struct CheckoutView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CheckoutViewModel

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
        self.onPaymentCompleted = onPaymentCompleted
    }

    var body: some View {
        let content =
        NavigationStack {
            VStack(spacing: 16) {
                Text("Checkout")
                    .font(.title3.weight(.semibold))

                Text("Order ID: \(viewModel.orderId)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if viewModel.isPreparing {
                    ProgressView("Preparation du paiement...")
                }

                if let message = viewModel.statusMessage {
                    Text(message)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                Button("Payer maintenant") {
                    Task { await viewModel.preparePaymentIfNeeded() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isPreparing)

                Button("Fermer") { dismiss() }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.preparePaymentIfNeeded() }
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

        // ✅ Applique paymentSheet uniquement si non-nil
        if let sheet = viewModel.paymentSheet {
            content
                .paymentSheet(
                    isPresented: $viewModel.isPresentingPaymentSheet,
                    paymentSheet: sheet
                ) { result in
                    viewModel.handlePaymentResult(result)
                    if case .completed = result {
                        onPaymentCompleted()
                        dismiss()
                    }
                }
        } else {
            content
        }
    }
}
