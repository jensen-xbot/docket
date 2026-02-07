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
    
    init(
        id: UUID = UUID(),
        userId: String? = nil,
        name: String,
        items: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.items = items
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
