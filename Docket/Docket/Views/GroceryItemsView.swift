import SwiftUI
import SwiftData

struct GroceryItemsView: View {
    @Bindable var store: GroceryStore
    
    @State private var newItem: String = ""
    
    var body: some View {
        List {
            Section("Add Item") {
                HStack(spacing: 8) {
                    TextField("Add item...", text: $newItem)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled()
                    Button(action: addItem) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Section("Items") {
                ForEach(store.items.indices, id: \.self) { index in
                    Text(store.items[index])
                }
                .onDelete(perform: deleteItems)
                .onMove(perform: moveItems)
            }
        }
        .navigationTitle(store.name)
        .environment(\.editMode, .constant(.active))
    }
    
    private func addItem() {
        let trimmed = newItem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.items.append(trimmed)
        store.updatedAt = Date()
        newItem = ""
    }
    
    private func deleteItems(at offsets: IndexSet) {
        store.items.remove(atOffsets: offsets)
        store.updatedAt = Date()
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        store.items.move(fromOffsets: source, toOffset: destination)
        store.updatedAt = Date()
    }
}

#Preview {
    let store = GroceryStore(name: "Costco", items: ["Tomato", "Cucumber", "Milk"])
    return NavigationStack {
        GroceryItemsView(store: store)
            .modelContainer(for: [Task.self, GroceryStore.self], inMemory: true)
    }
}
