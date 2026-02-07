import SwiftUI
import SwiftData

struct GroceryTemplateListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GroceryStore.name) private var stores: [GroceryStore]
    
    @State private var newStoreName: String = ""
    
    var body: some View {
        List {
            Section("Add Store") {
                HStack(spacing: 8) {
                    TextField("e.g. Costco", text: $newStoreName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                    Button(action: addStore) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Section("Templates") {
                ForEach(stores) { store in
                    NavigationLink {
                        GroceryItemsView(store: store)
                    } label: {
                        HStack {
                            Text(store.name)
                            Spacer()
                            Text("\(store.items.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            modelContext.delete(store)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            createTask(from: store)
                        } label: {
                            Label("Use", systemImage: "checklist")
                        }
                        .tint(.green)
                    }
                }
            }
        }
        .navigationTitle("Store Templates")
    }
    
    private func addStore() {
        let trimmed = newStoreName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let store = GroceryStore(name: trimmed)
        modelContext.insert(store)
        newStoreName = ""
    }
    
    private func createTask(from store: GroceryStore) {
        let items = store.items.enumerated().map { index, name in
            ChecklistItem(id: UUID(), name: name, isChecked: false, sortOrder: index)
        }
        let task = Task(
            title: store.name,
            priority: .medium,
            category: "Groceries",
            checklistItems: items,
            syncStatus: .pending
        )
        modelContext.insert(task)
    }
}

#Preview {
    NavigationStack {
        GroceryTemplateListView()
            .modelContainer(for: [Task.self, GroceryStore.self], inMemory: true)
    }
}
