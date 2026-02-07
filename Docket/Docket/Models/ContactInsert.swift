import Foundation

struct ContactInsert: Encodable {
    let userId: String
    let contactEmail: String
    let contactName: String?
    let contactPhone: String?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case contactEmail = "contact_email"
        case contactName = "contact_name"
        case contactPhone = "contact_phone"
    }
}
