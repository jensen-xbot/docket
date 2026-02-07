import Foundation
import SwiftData

@Model
class GroceryStore {
    @Attribute(.unique) var id: UUID
    var userId: String?
    var name: String
    var items: [String]
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: Int
    
    init(
        id: UUID = UUID(),
        userId: String? = nil,
        name: String,
        items: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncStatus: SyncStatus = .pending
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.items = items
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus.rawValue
    }
    
    var syncStatusEnum: SyncStatus {
        get { SyncStatus(rawValue: syncStatus) ?? .pending }
        set { syncStatus = newValue.rawValue }
    }
}

// Codable representation for Supabase sync
struct GroceryStoreDTO: Codable {
    let id: UUID
    let userId: String
    let name: String
    let items: [String]
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case items
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from store: GroceryStore, userId: String) {
        self.id = store.id
        self.userId = userId
        self.name = store.name
        self.items = store.items
        self.createdAt = store.createdAt
        self.updatedAt = store.updatedAt
    }
    
    func toGroceryStore() -> GroceryStore {
        GroceryStore(
            id: id,
            userId: userId,
            name: name,
            items: items,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncStatus: .synced
        )
    }
}
