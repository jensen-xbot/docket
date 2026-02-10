import Foundation

extension String {
    var isValidEmail: Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return self.range(of: pattern, options: .regularExpression) != nil
    }

    /// Strips to digits only for phone numbers (keeps leading +).
    var strippedPhoneNumber: String {
        let cleaned = filter { $0.isNumber || $0 == "+" }
        if cleaned.hasPrefix("+") {
            return "+" + cleaned.dropFirst().filter { $0.isNumber }
        }
        return cleaned.filter { $0.isNumber }
    }
}
