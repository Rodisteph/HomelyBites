import SwiftUI
import PassKit

// MARK: - Apple Pay Button (SwiftUI Wrapper)
struct ApplePayButton: View {
    let amount: Int  // Amount in cents
    let onSuccess: (PKPaymentToken) -> Void
    let onError: (Error) -> Void

    @State private var isPresentingPayment = false
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        Button(action: {
            presentApplePay()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "apple.logo")
                    .font(.dmSans(18, weight: .semibold))
                Text("Payer avec Apple Pay")
                    .font(.dmSans(16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black)
            )
        }
    }

    private func presentApplePay() {
        guard PKPaymentAuthorizationController.canMakePayments() else {
            onError(ApplePayError.notSupported)
            return
        }

        let request = PKPaymentRequest()
        request.merchantIdentifier = AppConfig.appleMerchantIdentifier
        request.supportedNetworks = [.visa, .masterCard, .amex, .discover]
        request.merchantCapabilities = .capability3DS
        request.countryCode = "FR"
        request.currencyCode = "EUR"

        let decimalAmount = NSDecimalNumber(value: Double(amount) / 100.0)
        let paymentItem = PKPaymentSummaryItem(
            label: "HomelyBites",
            amount: decimalAmount
        )
        request.paymentSummaryItems = [paymentItem]

        let controller = PKPaymentAuthorizationController(paymentRequest: request)
        controller.delegate = ApplePayCoordinator(
            onSuccess: onSuccess,
            onError: onError
        )
        controller.present { presented in
            if !presented {
                onError(ApplePayError.presentationFailed)
            }
        }
    }
}

// MARK: - Apple Pay Coordinator (Delegate)
private class ApplePayCoordinator: NSObject, PKPaymentAuthorizationControllerDelegate {
    let onSuccess: (PKPaymentToken) -> Void
    let onError: (Error) -> Void

    init(onSuccess: @escaping (PKPaymentToken) -> Void, onError: @escaping (Error) -> Void) {
        self.onSuccess = onSuccess
        self.onError = onError
    }

    func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didAuthorizePayment payment: PKPayment,
        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        // Extract the payment token
        let token = payment.token

        // Call success callback with the token
        onSuccess(token)

        // Complete the authorization with success
        // The actual payment confirmation should happen in the success callback
        completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
    }

    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss()
    }
}

// MARK: - Apple Pay Errors
enum ApplePayError: LocalizedError {
    case notSupported
    case presentationFailed
    case cancelled

    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "Apple Pay n'est pas disponible sur cet appareil."
        case .presentationFailed:
            return "Impossible d'afficher Apple Pay."
        case .cancelled:
            return "Paiement Apple Pay annulé."
        }
    }
}
