import Foundation

struct CountryCode: Identifiable, Hashable {
    var id: String { isoCode }
    let isoCode: String
    let name: String
    let dialCode: String
    
    var flag: String {
        let base: UInt32 = 127397
        return isoCode.uppercased().unicodeScalars.compactMap {
            UnicodeScalar(base + $0.value)
        }.map(String.init).joined()
    }
    
    var display: String { "\(flag) \(dialCode)" }
    var fullDisplay: String { "\(flag) \(name) (\(dialCode))" }
}

enum CountryCodes {
    static let all: [CountryCode] = [
        // North America
        CountryCode(isoCode: "US", name: "United States", dialCode: "+1"),
        CountryCode(isoCode: "CA", name: "Canada", dialCode: "+1"),
        CountryCode(isoCode: "MX", name: "Mexico", dialCode: "+52"),
        
        // Europe
        CountryCode(isoCode: "GB", name: "United Kingdom", dialCode: "+44"),
        CountryCode(isoCode: "DE", name: "Germany", dialCode: "+49"),
        CountryCode(isoCode: "FR", name: "France", dialCode: "+33"),
        CountryCode(isoCode: "ES", name: "Spain", dialCode: "+34"),
        CountryCode(isoCode: "IT", name: "Italy", dialCode: "+39"),
        CountryCode(isoCode: "NL", name: "Netherlands", dialCode: "+31"),
        CountryCode(isoCode: "PT", name: "Portugal", dialCode: "+351"),
        CountryCode(isoCode: "SE", name: "Sweden", dialCode: "+46"),
        CountryCode(isoCode: "NO", name: "Norway", dialCode: "+47"),
        CountryCode(isoCode: "DK", name: "Denmark", dialCode: "+45"),
        CountryCode(isoCode: "FI", name: "Finland", dialCode: "+358"),
        CountryCode(isoCode: "IE", name: "Ireland", dialCode: "+353"),
        CountryCode(isoCode: "CH", name: "Switzerland", dialCode: "+41"),
        CountryCode(isoCode: "AT", name: "Austria", dialCode: "+43"),
        CountryCode(isoCode: "BE", name: "Belgium", dialCode: "+32"),
        CountryCode(isoCode: "PL", name: "Poland", dialCode: "+48"),
        CountryCode(isoCode: "GR", name: "Greece", dialCode: "+30"),
        CountryCode(isoCode: "RO", name: "Romania", dialCode: "+40"),
        CountryCode(isoCode: "CZ", name: "Czech Republic", dialCode: "+420"),
        CountryCode(isoCode: "HU", name: "Hungary", dialCode: "+36"),
        CountryCode(isoCode: "UA", name: "Ukraine", dialCode: "+380"),
        CountryCode(isoCode: "RU", name: "Russia", dialCode: "+7"),
        
        // South America
        CountryCode(isoCode: "BR", name: "Brazil", dialCode: "+55"),
        CountryCode(isoCode: "AR", name: "Argentina", dialCode: "+54"),
        CountryCode(isoCode: "CO", name: "Colombia", dialCode: "+57"),
        CountryCode(isoCode: "CL", name: "Chile", dialCode: "+56"),
        CountryCode(isoCode: "PE", name: "Peru", dialCode: "+51"),
        
        // Asia
        CountryCode(isoCode: "JP", name: "Japan", dialCode: "+81"),
        CountryCode(isoCode: "KR", name: "South Korea", dialCode: "+82"),
        CountryCode(isoCode: "CN", name: "China", dialCode: "+86"),
        CountryCode(isoCode: "IN", name: "India", dialCode: "+91"),
        CountryCode(isoCode: "PH", name: "Philippines", dialCode: "+63"),
        CountryCode(isoCode: "TH", name: "Thailand", dialCode: "+66"),
        CountryCode(isoCode: "VN", name: "Vietnam", dialCode: "+84"),
        CountryCode(isoCode: "MY", name: "Malaysia", dialCode: "+60"),
        CountryCode(isoCode: "SG", name: "Singapore", dialCode: "+65"),
        CountryCode(isoCode: "ID", name: "Indonesia", dialCode: "+62"),
        CountryCode(isoCode: "PK", name: "Pakistan", dialCode: "+92"),
        CountryCode(isoCode: "BD", name: "Bangladesh", dialCode: "+880"),
        
        // Middle East
        CountryCode(isoCode: "AE", name: "UAE", dialCode: "+971"),
        CountryCode(isoCode: "SA", name: "Saudi Arabia", dialCode: "+966"),
        CountryCode(isoCode: "IL", name: "Israel", dialCode: "+972"),
        CountryCode(isoCode: "TR", name: "Turkey", dialCode: "+90"),
        
        // Africa
        CountryCode(isoCode: "ZA", name: "South Africa", dialCode: "+27"),
        CountryCode(isoCode: "NG", name: "Nigeria", dialCode: "+234"),
        CountryCode(isoCode: "EG", name: "Egypt", dialCode: "+20"),
        CountryCode(isoCode: "KE", name: "Kenya", dialCode: "+254"),
        CountryCode(isoCode: "GH", name: "Ghana", dialCode: "+233"),
        
        // Oceania
        CountryCode(isoCode: "AU", name: "Australia", dialCode: "+61"),
        CountryCode(isoCode: "NZ", name: "New Zealand", dialCode: "+64"),
        
        // Caribbean
        CountryCode(isoCode: "JM", name: "Jamaica", dialCode: "+1-876"),
        CountryCode(isoCode: "PR", name: "Puerto Rico", dialCode: "+1-787"),
        CountryCode(isoCode: "DO", name: "Dominican Republic", dialCode: "+1-809"),
    ]
    
    static func find(dialCode: String) -> CountryCode {
        all.first { $0.dialCode == dialCode } ?? all[0]
    }
    
    static func find(isoCode: String) -> CountryCode? {
        all.first { $0.isoCode.uppercased() == isoCode.uppercased() }
    }
}
