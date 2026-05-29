import SwiftUI
import StripePaymentSheet

struct CheckoutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CheckoutViewModel
    let onPaymentCompleted: () -> Void

    init(orderId: String, onPaymentCompleted: @escaping () -> Void) {
        _viewModel = State(initialValue: CheckoutViewModel(orderId: orderId))
        self.onPaymentCompleted = onPaymentCompleted
    }

    var body: some View {
        let content =
        NavigationStack {
            VStack(spacing: 16) {
                Text("Checkout").font(.title3.weight(.semibold))
                Text("Order ID : \(viewModel.orderId)").font(.caption).foregroundStyle(.secondary)

                if viewModel.isPreparing {
                    ProgressView("Préparation du paiement…")
                }
                if let message = viewModel.statusMessage {
                    Text(message).font(.footnote).multilineTextAlignment(.center).foregroundStyle(.secondary)
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
        .errorAlert(message: $viewModel.errorMessage)

        // PaymentSheet ne peut être appliqué que si non-nil
        if let sheet = viewModel.paymentSheet {
            content.paymentSheet(
                isPresented: $viewModel.isPresentingPaymentSheet,
                paymentSheet: sheet
            ) { result in
                viewModel.handlePaymentResult(result)
                if case .completed = result { onPaymentCompleted(); dismiss() }
            }
        } else {
            content
        }
    }
}
