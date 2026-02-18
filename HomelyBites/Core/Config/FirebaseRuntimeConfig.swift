import Foundation
import FirebaseCore

enum FirebaseRuntimeConfig {
    static let googleQuerySchemes = ["google", "com.google"]
    static let googleClientIDKey = "CLIENT_ID"
    static let googleReversedClientIDKey = "REVERSED_CLIENT_ID"

    static func googleClientID() -> String? {
        if let runtimeID = FirebaseApp.app()?.options.clientID?.trimmingCharacters(in: .whitespacesAndNewlines),
           !runtimeID.isEmpty {
            return runtimeID
        }

        if let plistID = plistStringValue(for: googleClientIDKey)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !plistID.isEmpty {
            return plistID
        }

        return nil
    }

    static func reversedClientID() -> String? {
        guard let value = plistStringValue(for: googleReversedClientIDKey)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    static func plistStringValue(for key: String) -> String? {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let dictionary = NSDictionary(contentsOfFile: path) as? [String: Any],
              let value = dictionary[key] as? String else {
            return nil
        }
        return value
    }

    static func masked(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 10 else {
            return "***"
        }
        return "\(trimmed.prefix(6))...\(trimmed.suffix(4))"
    }

    static func googleChecklist() -> String {
        "Checklist: 1) GoogleService-Info.plist present in app target resources, 2) CLIENT_ID and REVERSED_CLIENT_ID exist in plist, 3) Info.plist contains REVERSED_CLIENT_ID in CFBundleURLTypes, 4) FirebaseApp.configure() called once at launch."
    }
}
