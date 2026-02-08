import Foundation

struct CategoryItem: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var icon: String    // SF Symbol name (e.g. "briefcase.fill")
    var color: String   // Hex string (e.g. "#FF6B6B")
    
    init(id: UUID = UUID(), name: String, icon: String, color: String) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
    }
}

@MainActor
@Observable
class CategoryStore {
    static let shared = CategoryStore()
    
    private static let storageKey = "savedCategories"
    private static let legacyStorageKey = "savedCategories_legacy"
    
    var categories: [CategoryItem] = []
    
    // Default category mappings
    private static let defaultMappings: [String: (icon: String, color: String)] = [
        "Work": ("briefcase.fill", "#007AFF"),
        "Personal": ("person.fill", "#AF52DE"),
        "Family": ("house.fill", "#34C759"),
        "Health": ("heart.fill", "#FF3B30"),
        "Finance": ("dollarsign.circle.fill", "#5AC8FA"),
        "Groceries": ("cart.fill", "#FF9500"),
        "Shopping": ("bag.fill", "#FF2D55")
    ]
    
    init() {
        load()
    }
    
    private func load() {
        // Try to load new format first
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([CategoryItem].self, from: data) {
            categories = decoded
            return
        }
        
        // Migration: try to load old [String] format
        if let oldCategories = UserDefaults.standard.stringArray(forKey: Self.storageKey) {
            categories = oldCategories.map { name in
                let defaults = Self.defaultMappings[name] ?? ("tag.fill", "#8E8E93")
                return CategoryItem(name: name, icon: defaults.icon, color: defaults.color)
            }
            save() // Save in new format
            return
        }
        
        // Default categories
        categories = [
            CategoryItem(name: "Work", icon: "briefcase.fill", color: "#007AFF"),
            CategoryItem(name: "Personal", icon: "person.fill", color: "#AF52DE"),
            CategoryItem(name: "Family", icon: "house.fill", color: "#34C759"),
            CategoryItem(name: "Health", icon: "heart.fill", color: "#FF3B30"),
            CategoryItem(name: "Finance", icon: "dollarsign.circle.fill", color: "#5AC8FA"),
            CategoryItem(name: "Groceries", icon: "cart.fill", color: "#FF9500"),
            CategoryItem(name: "Shopping", icon: "bag.fill", color: "#FF2D55")
        ]
        save()
    }
    
    func add(_ category: String) {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !categories.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) else { return }
        let defaults = Self.defaultMappings[trimmed] ?? ("tag.fill", "#8E8E93")
        categories.append(CategoryItem(name: trimmed, icon: defaults.icon, color: defaults.color))
        save()
    }
    
    func addItem(_ item: CategoryItem) {
        let trimmed = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !categories.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) else { return }
        categories.append(item)
        save()
    }
    
    func remove(_ category: String) {
        categories.removeAll { $0.name == category }
        save()
    }
    
    func rename(oldName: String, newName: String) {
        guard let index = categories.firstIndex(where: { $0.name == oldName }) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !categories.contains(where: { $0.name.lowercased() == trimmed.lowercased() && $0.name != oldName }) else { return }
        categories[index].name = trimmed
        save()
    }
    
    func update(_ category: CategoryItem) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else { return }
        categories[index] = category
        save()
    }
    
    func find(byName name: String) -> CategoryItem? {
        categories.first { $0.name.lowercased() == name.lowercased() }
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(encoded, forKey: Self.storageKey)
        }
    }
}
