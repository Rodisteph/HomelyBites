import Foundation
import FirebaseFirestore
import StripePaymentSheet

@MainActor
final class CheckoutViewModel: ObservableObject {
    @Published var isPreparing = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?
    @Published var paymentSucceeded = false
    @Published var showPaymentSheet = false
    @Published var isAwaitingConfirmation = false
    @Published private(set) var paymentSheet: PaymentSheet?

    let orderId: String
    let amountCents: Int
    let itemLabel: String

    private let functionsService: CloudFunctionsService
    private let db = Firestore.firestore()
    private var orderListener: ListenerRegistration?
    private var awaitingWebhookConfirmation = false

    init(
        orderId: String,
        amountCents: Int,
        itemLabel: String,
        functionsService: CloudFunctionsService = CloudFunctionsService()
    ) {
        self.orderId = orderId
        self.amountCents = amountCents
        self.itemLabel = itemLabel
        self.functionsService = functionsService
        startOrderListener()
    }

    deinit {
        orderListener?.remove()
    }

    func preparePaymentSheet() async {
        guard !isPreparing, !isAwaitingConfirmation else { return }
        isPreparing = true
        defer { isPreparing = false }

        errorMessage = nil
        statusMessage = nil

        #if DEBUG
        debugLog("[Checkout][preparePaymentSheet] start orderId=\(orderId)")
        #endif

        do {
            let session = try await functionsService.createPaymentIntentWithFee(orderId: orderId)
            var configuration = PaymentSheet.Configuration()
            configuration.merchantDisplayName = "HomelyBites"
            configuration.returnURL = AppConfig.stripeReturnURL

            paymentSheet = PaymentSheet(
                paymentIntentClientSecret: session.clientSecret,
                configuration: configuration
            )
            showPaymentSheet = true

            #if DEBUG
            debugLog("[Checkout][preparePaymentSheet] ready orderId=\(session.orderId)")
            #endif
        } catch {
            #if DEBUG
            logNSErrorDetails(error, context: "preparePaymentSheet")
            #endif
            errorMessage = error.localizedDescription
        }
    }

    func handlePaymentSheetResult(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            awaitingWebhookConfirmation = true
            isAwaitingConfirmation = true
            statusMessage = "Confirmation en cours..."
            #if DEBUG
            debugLog("[Checkout][handlePaymentSheetResult] completed awaiting_webhook orderId=\(orderId)")
            #endif
        case .canceled:
            awaitingWebhookConfirmation = false
            isAwaitingConfirmation = false
            statusMessage = "Paiement annulé."
            #if DEBUG
            debugLog("[Checkout][handlePaymentSheetResult] canceled orderId=\(orderId)")
            #endif
        case .failed(let error):
            awaitingWebhookConfirmation = false
            isAwaitingConfirmation = false
            errorMessage = error.localizedDescription
            #if DEBUG
            logNSErrorDetails(error, context: "handlePaymentSheetResult.failed")
            #endif
        }
    }

    private func startOrderListener() {
        orderListener?.remove()
        orderListener = db.collection("orders").document(orderId).addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            Task { @MainActor in
                if let error {
                    #if DEBUG
                    self.logNSErrorDetails(error, context: "orderListener")
                    #endif
                    self.errorMessage = error.localizedDescription
                    return
                }

                guard let data = snapshot?.data(),
                      let paymentStatusRaw = data["paymentStatus"] as? String,
                      let paymentStatus = PaymentStatus(rawValue: paymentStatusRaw) else {
                    return
                }

                switch paymentStatus {
                case .requires_payment:
                    if self.awaitingWebhookConfirmation {
                        self.statusMessage = "Confirmation en cours..."
                    }
                case .paid:
                    self.awaitingWebhookConfirmation = false
                    self.isAwaitingConfirmation = false
                    self.statusMessage = "Paiement confirmé."
                    self.paymentSucceeded = true
                case .failed:
                    self.awaitingWebhookConfirmation = false
                    self.isAwaitingConfirmation = false
                    self.statusMessage = nil
                    self.errorMessage = "Paiement refusé. Réessaie avec un autre moyen de paiement."
                case .refunded:
                    self.awaitingWebhookConfirmation = false
                    self.isAwaitingConfirmation = false
                    self.statusMessage = "Paiement remboursé."
                }
            }
        }
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        NSLog("%@", message)
        #endif
    }

    private func logNSErrorDetails(_ error: Error, context: String) {
        #if DEBUG
        let nsError = error as NSError
        debugLog("[Checkout][\(context)] domain=\(nsError.domain) code=\(nsError.code)")
        debugLog("[Checkout][\(context)] localizedDescription=\(nsError.localizedDescription)")
        debugLog("[Checkout][\(context)] userInfo=\(nsError.userInfo)")
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            debugLog("[Checkout][\(context)] underlying.domain=\(underlying.domain) code=\(underlying.code)")
            debugLog("[Checkout][\(context)] underlying.localizedDescription=\(underlying.localizedDescription)")
            debugLog("[Checkout][\(context)] underlying.userInfo=\(underlying.userInfo)")
        }
        #endif
    }
}
