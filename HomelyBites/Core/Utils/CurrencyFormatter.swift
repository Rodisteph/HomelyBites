import Foundation

extension Int {
    func asEuro() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle  = .currency
        formatter.currencyCode = "EUR"
        formatter.locale       = Locale(identifier: "fr_FR")
        return formatter.string(from: NSNumber(value: Double(self) / 100.0)) ?? "\(self) EUR"
    }
}
