import Foundation

@MainActor
@Observable
class CategoryStore {
    private static let storageKey = "savedCategories"
    
    var categories: [String] = []
    
    init() {
        load()
    }
    
    private func load() {
        categories = UserDefaults.standard.stringArray(forKey: Self.storageKey) ?? [
            "Work", "Personal", "Family", "Health", "Finance", "Groceries", "Shopping"
        ]
    }
    
    func add(_ category: String) {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !categories.contains(trimmed) else { return }
        categories.append(trimmed)
        save()
    }
    
    func remove(_ category: String) {
        categories.removeAll { $0 == category }
        save()
    }
    
    private func save() {
        UserDefaults.standard.set(categories, forKey: Self.storageKey)
    }
}
