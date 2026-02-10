import Foundation

/// Fuzzy contact matching for voice share resolution.
/// Handles spelling variants (e.g., "Taryn" → "Tarryn") via Levenshtein distance.
enum FuzzyContactMatcher {
    /// Maximum edit distance for a match (e.g., 2 allows "Taryn" ↔ "Tarryn")
    static let maxEditDistance = 2

    /// Resolves a name to a contact from the list.
    /// - First tries exact/case-insensitive match on contact_name
    /// - If no match, returns best fuzzy match if edit distance <= maxEditDistance
    /// - Returns nil if no reasonable match
    static func resolveContact(name: String, from contacts: [ContactRecord]) -> ContactRecord? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()

        // 1. Exact or case-insensitive match on full name
        if let exact = contacts.first(where: { contactName(for: $0).lowercased() == lower }) {
            return exact
        }

        // 2. Exact match on any name part (first name, last name)
        //    e.g. "Taryn" == first part of "Taryn Smith"
        if let partMatch = contacts.first(where: {
            contactName(for: $0).lowercased()
                .split(separator: " ")
                .contains(where: { String($0) == lower })
        }) {
            return partMatch
        }

        // 3. Contains match (e.g., "Taryn" substring in "Taryn Smith")
        if let contains = contacts.first(where: { contactName(for: $0).lowercased().contains(lower) }) {
            return contains
        }

        // 4. Fuzzy match by Levenshtein distance — compare against full name AND each name part
        //    e.g. "Taryn" vs "Tarryn" (first name of "Tarryn Klibingat") → distance 1
        var best: (contact: ContactRecord, distance: Int)?
        for contact in contacts {
            let fullName = contactName(for: contact)
            guard !fullName.isEmpty else { continue }

            let fullNameLower = fullName.lowercased()
            let nameParts = fullNameLower.split(separator: " ").map(String.init)

            // Try full name first
            let fullDistance = levenshteinDistance(lower, fullNameLower)
            if fullDistance <= maxEditDistance {
                if best == nil || fullDistance < best!.distance {
                    best = (contact, fullDistance)
                }
            }

            // Try each name part (first name, last name, etc.)
            for part in nameParts {
                let partDistance = levenshteinDistance(lower, part)
                if partDistance <= maxEditDistance {
                    if best == nil || partDistance < best!.distance {
                        best = (contact, partDistance)
                    }
                }
            }
        }
        return best?.contact
    }

    private static func contactName(for contact: ContactRecord) -> String {
        contact.contactName ?? contact.contactEmail
    }

    /// Levenshtein (edit) distance between two strings.
    private static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        let m = a.count
        let n = b.count

        if m == 0 { return n }
        if n == 0 { return m }

        var dp = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)
        for i in 0...m { dp[i][0] = i }
        for j in 0...n { dp[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                dp[i][j] = min(
                    dp[i - 1][j] + 1,
                    dp[i][j - 1] + 1,
                    dp[i - 1][j - 1] + cost
                )
            }
        }
        return dp[m][n]
    }
}
