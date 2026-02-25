import Foundation
import FirebaseAuth
import FirebaseFunctions

struct OrderCheckoutSession {
    let orderId: String
    let clientSecret: String
}

struct ConnectAccountSession {
    let accountId: String
    let onboardingURL: URL?
    let status: String
    let alreadyExists: Bool
}

struct StripeAccountStatus {
    let accountId: String
    let stripeOnboarded: Bool
    let stripeStatus: String
    let payoutsEnabled: Bool?
    let chargesEnabled: Bool?
    let requirements: [String: [String]]?
}

struct MealLocationBackfillResult {
    let processedCount: Int
    let updatedCount: Int
    let dryRun: Bool
}

final class CloudFunctionsService {
    private let functions = Functions.functions(region: AppConfig.firebaseFunctionsRegion)
    private let auth = Auth.auth()

    private func call(_ name: String, data: [String: Any]) async throws -> Any {
        guard auth.currentUser != nil else {
            #if DEBUG
            debugLog("[Functions][\(name)] blocked: unauthenticated user")
            #endif
            throw AppError.missingAuth
        }

        #if DEBUG
        debugLog("[Functions][\(name)] request uid=\(auth.currentUser?.uid ?? "nil") payload=\(redactedPayload(data))")
        #endif

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Any, Error>) in
            functions.httpsCallable(name).call(data) { result, error in
                if let error {
                    #if DEBUG
                    self.logNSErrorDetails(error, context: name)
                    #endif
                    continuation.resume(throwing: self.mapFunctionsError(error, functionName: name))
                    return
                }
                guard let result else {
                    continuation.resume(throwing: AppError.invalidResponse)
                    return
                }
                #if DEBUG
                self.debugLog("[Functions][\(name)] success")
                #endif
                continuation.resume(returning: result.data)
            }
        }
    }

    func createConnectAccount() async throws -> ConnectAccountSession {
        let response = try await call("createConnectAccount", data: [:])
        guard let payload = response as? [String: Any],
              let accountId = payload["accountId"] as? String else {
            throw AppError.invalidResponse
        }

        let onboardingURL: URL?
        if let onboardingURLString = payload["onboardingUrl"] as? String,
           let parsedURL = URL(string: onboardingURLString) {
            onboardingURL = parsedURL
        } else {
            onboardingURL = nil
        }

        let status = (payload["status"] as? String) ?? "not_ready"
        let alreadyExists = (payload["alreadyExists"] as? Bool) ?? false

        return ConnectAccountSession(
            accountId: accountId,
            onboardingURL: onboardingURL,
            status: status,
            alreadyExists: alreadyExists
        )
    }

    func createOnboardingLink() async throws -> URL {
        let response = try await call("createOnboardingLink", data: [:])
        guard let payload = response as? [String: Any],
              let urlString = payload["url"] as? String,
              let url = URL(string: urlString) else {
            throw AppError.invalidResponse
        }
        return url
    }

    func refreshStripeStatus() async throws -> StripeAccountStatus {
        let response = try await call("refreshStripeStatus", data: [:])
        guard let payload = response as? [String: Any],
              let accountId = payload["accountId"] as? String,
              let stripeOnboarded = payload["stripeOnboarded"] as? Bool,
              let stripeStatus = payload["stripeStatus"] as? String else {
            throw AppError.invalidResponse
        }
        return StripeAccountStatus(
            accountId: accountId,
            stripeOnboarded: stripeOnboarded,
            stripeStatus: stripeStatus,
            payoutsEnabled: payload["payoutsEnabled"] as? Bool,
            chargesEnabled: payload["chargesEnabled"] as? Bool,
            requirements: payload["requirements"] as? [String: [String]]
        )
    }

    func getConnectStatus() async throws -> StripeAccountStatus {
        let response = try await call("getConnectStatus", data: [:])
        guard let payload = response as? [String: Any],
              let accountId = payload["accountId"] as? String else {
            throw AppError.invalidResponse
        }

        let rawStatus = (payload["status"] as? String) ?? "not_ready"
        let stripeStatus = rawStatus == "enabled" ? "ready" : rawStatus
        let stripeOnboarded = rawStatus == "enabled"

        return StripeAccountStatus(
            accountId: accountId,
            stripeOnboarded: stripeOnboarded,
            stripeStatus: stripeStatus,
            payoutsEnabled: payload["payoutsEnabled"] as? Bool,
            chargesEnabled: payload["chargesEnabled"] as? Bool,
            requirements: payload["requirements"] as? [String: [String]]
        )
    }

    func deleteMeal(mealId: String) async throws {
        let trimmedMealId = mealId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMealId.isEmpty else {
            throw AppError.invalidInput("mealId manquant pour supprimer le repas.")
        }

        let response = try await call("deleteMeal", data: [
            "mealId": trimmedMealId
        ])

        guard let payload = response as? [String: Any],
              let ok = payload["ok"] as? Bool,
              ok == true else {
            throw AppError.invalidResponse
        }
    }

    func acknowledgeHaccp(version: String = "2026-02") async throws {
        let response = try await call("acknowledgeHaccp", data: [
            "version": version
        ])

        guard let payload = response as? [String: Any],
              let ok = payload["ok"] as? Bool,
              ok == true else {
            throw AppError.invalidResponse
        }
    }

    func backfillMealLocations(onlyMine: Bool = true, dryRun: Bool = false) async throws -> MealLocationBackfillResult {
        let response = try await call("backfillMealLocations", data: [
            "onlyMine": onlyMine,
            "dryRun": dryRun
        ])

        guard let payload = response as? [String: Any],
              let ok = payload["ok"] as? Bool,
              ok == true else {
            throw AppError.invalidResponse
        }

        return MealLocationBackfillResult(
            processedCount: payload["processedCount"] as? Int ?? 0,
            updatedCount: payload["updatedCount"] as? Int ?? 0,
            dryRun: payload["dryRun"] as? Bool ?? dryRun
        )
    }

    func createOrderAndPaymentIntent(
        mealId: String,
        portions: Int,
        note: String,
        serviceMode: MealServiceMode? = nil
    ) async throws -> OrderCheckoutSession {
        guard !mealId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.invalidInput("mealId manquant pour creer le paiement.")
        }
        guard portions > 0 else {
            throw AppError.invalidInput("Le nombre de portions doit etre superieur a 0.")
        }

        var payload: [String: Any] = [
            "mealId": mealId,
            "portions": portions,
            "note": note
        ]
        if let serviceMode {
            payload["serviceMode"] = serviceMode.rawValue
        }

        #if DEBUG
        debugLog("[Functions][createOrderAndPaymentIntent] start mealId=\(mealId) portions=\(portions) serviceMode=\(serviceMode?.rawValue ?? "nil")")
        #endif

        let response = try await call("createOrderAndPaymentIntent", data: payload)

        guard let payload = response as? [String: Any],
              let orderId = payload["orderId"] as? String,
              let clientSecret = payload["clientSecret"] as? String,
              !orderId.isEmpty,
              !clientSecret.isEmpty else {
            #if DEBUG
            debugLog("[Functions][createOrderAndPaymentIntent] invalid payload=\(String(describing: response))")
            #endif
            throw AppError.invalidResponse
        }

        #if DEBUG
        debugLog("[Functions][createOrderAndPaymentIntent] result orderId=\(orderId)")
        #endif

        return OrderCheckoutSession(orderId: orderId, clientSecret: clientSecret)
    }

    func transitionOrderStatus(orderId: String, to status: OrderStatus) async throws {
        _ = try await call("transitionOrderStatus", data: [
            "orderId": orderId,
            "nextStatus": status.rawValue
        ])
    }

    func confirmPaymentWithApplePay(
        orderId: String,
        applePayToken: String
    ) async throws {
        guard !orderId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.invalidInput("orderId manquant pour confirmer le paiement Apple Pay.")
        }
        guard !applePayToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.invalidInput("Token Apple Pay manquant.")
        }

        #if DEBUG
        debugLog("[Functions][confirmPaymentWithApplePay] start orderId=\(orderId)")
        #endif

        let response = try await call("confirmApplePayPayment", data: [
            "orderId": orderId,
            "applePayToken": applePayToken
        ])

        guard let payload = response as? [String: Any],
              let ok = payload["ok"] as? Bool,
              ok == true else {
            #if DEBUG
            debugLog("[Functions][confirmPaymentWithApplePay] invalid payload=\(String(describing: response))")
            #endif
            throw AppError.invalidResponse
        }

        #if DEBUG
        debugLog("[Functions][confirmPaymentWithApplePay] success orderId=\(orderId)")
        #endif
    }

    private func redactedPayload(_ payload: [String: Any]) -> String {
        let safe = payload.mapValues { value -> Any in
            if let stringValue = value as? String, stringValue.count > 120 {
                return "\(stringValue.prefix(117))..."
            }
            return value
        }
        return String(describing: safe)
    }

    private func mapFunctionsError(_ error: Error, functionName: String) -> Error {
        let nsError = error as NSError
        guard nsError.domain == FunctionsErrorDomain,
              let code = FunctionsErrorCode(rawValue: nsError.code) else {
            return error
        }

        let rawMessage = extractFunctionsMessage(from: nsError)
            ?? (nsError.userInfo[NSLocalizedDescriptionKey] as? String)
            ?? nsError.localizedDescription
        let functionMessage = normalizedFunctionsMessage(
            rawMessage: rawMessage,
            code: code,
            functionName: functionName
        )

        switch code {
        case .unauthenticated:
            return AppError.missingAuth
        case .invalidArgument,
                .failedPrecondition,
                .permissionDenied,
                .notFound,
                .internal,
                .unavailable,
                .dataLoss,
                .unknown:
            return AppError.invalidInput(functionMessage)
        default:
            return AppError.invalidInput(functionMessage)
        }
    }

    private func extractFunctionsMessage(from nsError: NSError) -> String? {
        if let details = nsError.userInfo[FunctionsErrorDetailsKey] as? String, !details.isEmpty {
            return details
        }
        if let details = nsError.userInfo[FunctionsErrorDetailsKey] as? [String: Any],
           let message = extractMessage(from: details) {
            return message
        }
        if let details = nsError.userInfo[FunctionsErrorDetailsKey] as? [[String: Any]],
           let first = details.first,
           let message = extractMessage(from: first) {
            return message
        }
        if let failureReason = nsError.userInfo[NSLocalizedFailureReasonErrorKey] as? String,
           !failureReason.isEmpty {
            return failureReason
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
           let message = extractFunctionsMessage(from: underlying) {
            return message
        }
        return nil
    }

    private func extractMessage(from details: [String: Any]) -> String? {
        for key in ["message", "error", "description", "reason"] {
            if let value = details[key] as? String, !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private func normalizedFunctionsMessage(
        rawMessage: String,
        code: FunctionsErrorCode,
        functionName: String
    ) -> String {
        if !isGenericFunctionsMessage(rawMessage, code: code) {
            return rawMessage
        }
        return fallbackFunctionsMessage(code: code, functionName: functionName)
    }

    private func isGenericFunctionsMessage(_ message: String, code: FunctionsErrorCode) -> Bool {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return true
        }
        let upper = trimmed.uppercased()
        if upper == "INTERNAL" || upper == "UNKNOWN" || upper == "UNAUTHENTICATED" {
            return true
        }
        if upper == String(describing: code).uppercased() {
            return true
        }
        if upper == "THE OPERATION COULDN'T BE COMPLETED. (INTERNAL.)" {
            return true
        }
        return false
    }

    private func fallbackFunctionsMessage(code: FunctionsErrorCode, functionName: String) -> String {
        switch (functionName, code) {
        case ("createConnectAccount", .failedPrecondition):
            return "Stripe n'est pas configure sur le backend (secret manquant) ou le profil host est incomplet."
        case ("createConnectAccount", .permissionDenied):
            return "Compte host requis pour activer les paiements."
        case ("createConnectAccount", .internal):
            return "Erreur interne pendant la creation du compte Stripe. Verifie les logs Functions createConnectAccount."
        case ("createOnboardingLink", .failedPrecondition):
            return "Compte Stripe introuvable ou onboarding non initialise. Active d'abord les paiements."
        case ("refreshStripeStatus", .failedPrecondition):
            return "Aucun compte Stripe associe a ce host."
        case ("getConnectStatus", .failedPrecondition):
            return "Aucun compte Stripe associe a ce host."
        case ("deleteMeal", .permissionDenied):
            return "Suppression refusee: ce repas ne t'appartient pas."
        case ("deleteMeal", .notFound):
            return "Ce repas n'existe plus."
        case ("deleteMeal", .internal):
            return "Erreur serveur pendant la suppression du repas. Verifie les logs Functions deleteMeal."
        case ("acknowledgeHaccp", .permissionDenied):
            return "Compte host requis pour valider HACCP."
        case ("acknowledgeHaccp", .internal):
            return "Erreur serveur pendant la validation HACCP."
        case ("backfillMealLocations", .permissionDenied):
            return "Backfill global reserve a un compte admin."
        case ("backfillMealLocations", .internal):
            return "Erreur serveur pendant le backfill location."
        case ("createOrderAndPaymentIntent", .failedPrecondition):
            return "Ce mode de service n'est pas disponible pour ce repas."
        case (_, .unauthenticated):
            return AppError.missingAuth.localizedDescription
        case (_, .permissionDenied):
            return "Permission refusee."
        case (_, .notFound):
            return "Ressource introuvable."
        case (_, .failedPrecondition):
            return "Condition invalide cote serveur."
        case (_, .invalidArgument):
            return "Donnees invalides envoyees au serveur."
        case (_, .internal):
            return "Erreur interne Cloud Function. Consulte les logs Firebase Functions."
        case (_, .unavailable):
            return "Service temporairement indisponible. Reessaie."
        default:
            return "Erreur Cloud Function (\(code.rawValue))."
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
        debugLog("[Functions][\(context)] domain=\(nsError.domain) code=\(nsError.code)")
        debugLog("[Functions][\(context)] localizedDescription=\(nsError.localizedDescription)")
        debugLog("[Functions][\(context)] userInfo=\(nsError.userInfo)")
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            debugLog("[Functions][\(context)] underlying.domain=\(underlying.domain) code=\(underlying.code)")
            debugLog("[Functions][\(context)] underlying.localizedDescription=\(underlying.localizedDescription)")
            debugLog("[Functions][\(context)] underlying.userInfo=\(underlying.userInfo)")
        }
        #endif
    }
}
