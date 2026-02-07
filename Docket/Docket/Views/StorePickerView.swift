import SwiftUI

struct StorePickerView: View {
    @Binding var selectedStore: String
    @State private var storeStore = StoreStore()
    @State private var newStore = ""
    @State private var isAddingNew = false
    @FocusState private var newStoreFocused: Bool
    var onStoreChanged: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Store")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // Existing stores as chips
            FlowLayout(spacing: 8) {
                ForEach(storeStore.stores, id: \.self) { store in
                    Button {
                        if selectedStore == store {
                            selectedStore = ""
                        } else {
                            selectedStore = store
                        }
                        onStoreChanged?()
                    } label: {
                        Text(store)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedStore == store ? Color.orange : Color(.systemGray6))
                            .foregroundStyle(selectedStore == store ? .white : .primary)
                            .cornerRadius(16)
                    }
                }
                
                // Add new button
                Button {
                    isAddingNew = true
                    newStoreFocused = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.caption)
                        Text("New")
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .foregroundStyle(.secondary)
                    .cornerRadius(16)
                }
            }
            
            // Add new store input
            if isAddingNew {
                HStack(spacing: 8) {
                    TextField("New store", text: $newStore)
                        .font(.subheadline)
                        .focused($newStoreFocused)
                        .onSubmit { addStore() }
                    
                    Button(action: addStore) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                    .disabled(newStore.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    Button {
                        isAddingNew = false
                        newStore = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            }
        }
    }
    
    private func addStore() {
        let trimmed = newStore.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        storeStore.add(trimmed)
        selectedStore = trimmed
        newStore = ""
        isAddingNew = false
        onStoreChanged?()
    }
    
    /// Check if a store name exists in the store list
    func contains(_ store: String) -> Bool {
        storeStore.contains(store)
    }
    
    /// Find matching store name (case-insensitive)
    func match(_ store: String) -> String? {
        storeStore.match(store)
    }
}

#Preview {
    @Previewable @State var store = ""
    StorePickerView(selectedStore: $store)
        .padding()
}
