import Foundation

extension Int {
    func asEuro() -> String {
        let value = Double(self) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: NSNumber(value: value)) ?? "\(value) EUR"
    }
}
