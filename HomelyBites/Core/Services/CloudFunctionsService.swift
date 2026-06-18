import Foundation
import FirebaseFunctions

final class CloudFunctionsService {

    private let functions = Functions.functions(region: AppConfig.firebaseFunctionsRegion)

    private func call(_ name: String, data: [String: Any] = [:]) async throws -> [String: Any] {
        let result = try await functions.httpsCallable(name).call(data)
        guard let payload = result.data as? [String: Any] else {
            throw AppError.invalidResponse
        }
        return payload
    }

    func createConnectAccount() async throws -> String {
        let payload = try await call("createConnectAccount")
        guard let accountId = payload["accountId"] as? String else {
            throw AppError.invalidResponse
        }
        return accountId
    }

    func createOnboardingLink() async throws -> URL {
        let payload = try await call("createOnboardingLink")
        guard
            let urlString = payload["url"] as? String,
            let url = URL(string: urlString)
        else { throw AppError.invalidResponse }
        return url
    }

    func createPaymentIntentWithFee(orderId: String) async throws -> String {
        let payload = try await call("createPaymentIntentWithFee", data: ["orderId": orderId])
        guard
            let clientSecret = payload["clientSecret"] as? String,
            !clientSecret.isEmpty
        else { throw AppError.invalidResponse }
        return clientSecret
    }
}
