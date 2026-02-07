import Foundation

struct UserProfile: Codable {
    let id: UUID
    var displayName: String?
    var email: String?
    var phone: String?
    var countryIso: String?
    var avatarUrl: String?
    var avatarEmoji: String?
    var createdAt: Date?
    var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case email
        case phone
        case countryIso = "country_iso"
        case avatarUrl = "avatar_url"
        case avatarEmoji = "avatar_emoji"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct UserProfileUpsert: Encodable {
    let id: UUID
    var displayName: String?
    var email: String?
    var phone: String?
    var countryIso: String?
    var avatarUrl: String?
    var avatarEmoji: String?
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case email
        case phone
        case countryIso = "country_iso"
        case avatarUrl = "avatar_url"
        case avatarEmoji = "avatar_emoji"
        case updatedAt = "updated_at"
    }
}
