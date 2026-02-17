import Foundation
import FirebaseFunctions

final class CloudFunctionsService {
    private let functions = Functions.functions(region: AppConfig.firebaseFunctionsRegion)

    private func call(_ name: String, data: [String: Any]) async throws -> Any {
        try await withCheckedThrowingContinuation { continuation in
            functions.httpsCallable(name).call(data) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result else {
                    continuation.resume(throwing: AppError.invalidResponse)
                    return
                }
                continuation.resume(returning: result.data)
            }
        }
    }

    func createConnectAccount() async throws -> String {
        let response = try await call("createConnectAccount", data: [:])
        guard let payload = response as? [String: Any],
              let accountId = payload["accountId"] as? String else {
            throw AppError.invalidResponse
        }
        return accountId
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

    func createPaymentIntentWithFee(orderId: String) async throws -> String {
        let response = try await call("createPaymentIntentWithFee", data: [
            "orderId": orderId
        ])

        guard let payload = response as? [String: Any],
              let clientSecret = payload["clientSecret"] as? String,
              !clientSecret.isEmpty else {
            throw AppError.invalidResponse
        }

        return clientSecret
    }
}
