import SwiftUI
import PassKit

// MARK: - Apple Pay Button (Native PKPaymentButton wrapper)
struct ApplePayButton: View {
    let amount: Int  // Amount in cents
    let onSuccess: (PKPaymentToken) -> Void
    let onError: (Error) -> Void

    var body: some View {
        ApplePayButtonRepresentable(action: presentApplePay)
            .frame(maxWidth: .infinity, minHeight: 52)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

        let coordinator = ApplePayCoordinator(
            onSuccess: onSuccess,
            onError: onError
        )
        // Retain coordinator for the duration of the payment flow
        ApplePayCoordinatorHolder.shared.current = coordinator

        let controller = PKPaymentAuthorizationController(paymentRequest: request)
        controller.delegate = coordinator
        controller.present { presented in
            if !presented {
                ApplePayCoordinatorHolder.shared.current = nil
                onError(ApplePayError.presentationFailed)
            }
        }
    }
}

// MARK: - Native PKPaymentButton UIKit Representable
private struct ApplePayButtonRepresentable: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> PKPaymentButton {
        let button = PKPaymentButton(paymentButtonType: .buy, paymentButtonStyle: .black)
        button.cornerRadius = 12
        button.addTarget(context.coordinator, action: #selector(Coordinator.didTap), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: PKPaymentButton, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) {
            self.action = action
        }
        @objc func didTap() {
            action()
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
        let token = payment.token
        onSuccess(token)
        completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
    }

    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss()
        ApplePayCoordinatorHolder.shared.current = nil
    }
}

// MARK: - Coordinator Holder (prevents ARC deallocation during payment)
private class ApplePayCoordinatorHolder {
    static let shared = ApplePayCoordinatorHolder()
    var current: ApplePayCoordinator?
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
