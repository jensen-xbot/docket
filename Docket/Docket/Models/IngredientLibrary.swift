import Foundation
import SwiftData

@Model
class IngredientLibrary {
    @Attribute(.unique) var id: UUID
    var userId: String?
    var name: String
    var displayName: String
    var useCount: Int
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: Int
    
    init(
        id: UUID = UUID(),
        userId: String? = nil,
        name: String,
        displayName: String,
        useCount: Int = 1,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncStatus: SyncStatus = .pending
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.displayName = displayName
        self.useCount = useCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus.rawValue
    }
    
    var syncStatusEnum: SyncStatus {
        get { SyncStatus(rawValue: syncStatus) ?? .pending }
        set { syncStatus = newValue.rawValue }
    }
}

struct IngredientLibraryDTO: Codable {
    let id: UUID
    let userId: String
    let name: String
    let displayName: String
    let useCount: Int
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case displayName = "display_name"
        case useCount = "use_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from ingredient: IngredientLibrary, userId: String) {
        self.id = ingredient.id
        self.userId = userId
        self.name = ingredient.name
        self.displayName = ingredient.displayName
        self.useCount = ingredient.useCount
        self.createdAt = ingredient.createdAt
        self.updatedAt = ingredient.updatedAt
    }
    
    func toIngredientLibrary() -> IngredientLibrary {
        IngredientLibrary(
            id: id,
            userId: userId,
            name: name,
            displayName: displayName,
            useCount: useCount,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncStatus: .synced
        )
    }
}

enum IngredientSeeds {
    static let common: [String] = [
        "apples", "bananas", "berries", "blueberries", "strawberries", "grapes",
        "oranges", "lemons", "limes", "pears", "pineapple", "mango", "avocado",
        "tomatoes", "cherry tomatoes", "cucumbers", "lettuce", "spinach",
        "kale", "broccoli", "cauliflower", "carrots", "celery", "onions",
        "green onions", "garlic", "ginger", "potatoes", "sweet potatoes",
        "mushrooms", "zucchini", "bell peppers", "jalapenos", "corn",
        "peas", "green beans", "asparagus",
        "milk", "cream", "butter", "yogurt", "greek yogurt", "cheddar",
        "mozzarella", "parmesan", "eggs",
        "chicken", "ground beef", "steak", "pork", "bacon", "ham",
        "salmon", "tuna", "shrimp",
        "bread", "bagels", "tortillas", "pasta", "rice", "quinoa",
        "cereal", "oats", "flour", "sugar", "brown sugar",
        "olive oil", "vegetable oil", "vinegar", "soy sauce", "hot sauce",
        "ketchup", "mustard", "mayonnaise", "bbq sauce",
        "salt", "pepper", "paprika", "cumin", "chili powder", "oregano",
        "basil", "thyme", "cinnamon", "vanilla",
        "beans", "black beans", "chickpeas", "lentils",
        "nuts", "almonds", "peanuts", "cashews",
        "chips", "crackers", "cookies", "chocolate",
        "coffee", "tea", "juice", "sparkling water"
    ]
}
