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

    func createPaymentIntent(orderId: String) async throws -> String {
        let payload = try await call("createPaymentIntent", data: ["orderId": orderId])
        guard
            let clientSecret = payload["clientSecret"] as? String,
            !clientSecret.isEmpty
        else { throw AppError.invalidResponse }
        return clientSecret
    }
}
