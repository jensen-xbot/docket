import Foundation

@MainActor
@Observable
class StoreStore {
    private static let storageKey = "savedStores"
    
    var stores: [String] = []
    
    init() {
        load()
    }
    
    private func load() {
        stores = UserDefaults.standard.stringArray(forKey: Self.storageKey) ?? [
            "Costco", "Metro", "IGA", "Loblaws", "Maxi"
        ]
    }
    
    func add(_ store: String) {
        let trimmed = store.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !stores.contains(trimmed) else { return }
        stores.append(trimmed)
        save()
    }
    
    func remove(_ store: String) {
        stores.removeAll { $0 == store }
        save()
    }
    
    func rename(oldName: String, newName: String) {
        guard let index = stores.firstIndex(where: { $0 == oldName }) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !stores.contains(where: { $0.lowercased() == trimmed.lowercased() && $0 != oldName }) else { return }
        stores[index] = trimmed
        save()
    }
    
    func contains(_ store: String) -> Bool {
        stores.contains(where: { $0.lowercased() == store.lowercased() })
    }
    
    func match(_ store: String) -> String? {
        stores.first(where: { $0.lowercased() == store.lowercased() })
    }
    
    private func save() {
        UserDefaults.standard.set(stores, forKey: Self.storageKey)
    }
}
