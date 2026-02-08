import SwiftUI

struct StorePickerView: View {
    @Binding var selectedStore: String
    @State private var storeStore = StoreStore()
    @State private var isAddingNew = false
    @State private var newStoreName: String = ""
    @State private var isEditMode = false
    @State private var editingStore: String? = nil
    @State private var editingStoreName: String = ""
    @FocusState private var editFieldFocused: Bool
    @FocusState private var newStoreFocused: Bool
    var onStoreChanged: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            Text("Store")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // Store chips with edit toggle inline
            FlowLayout(spacing: 8) {
                ForEach(storeStore.stores, id: \.self) { store in
                    if isEditMode {
                        if editingStore == store {
                            renamingChip(for: store)
                        } else {
                            editableChip(for: store)
                        }
                    } else {
                        normalChip(for: store)
                    }
                }
                
                // Inline new store pill or "+ New" button
                if isAddingNew {
                    newStoreChip()
                } else if !isEditMode {
                    Button {
                        isAddingNew = true
                        newStoreName = ""
                        newStoreFocused = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.caption)
                            Text("New")
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .foregroundStyle(.secondary)
                        .cornerRadius(16)
                    }
                }
                
                // Edit / Done toggle — inline as last chip
                Button {
                    toggleEditMode()
                } label: {
                    if isEditMode {
                        Text("Done")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.12))
                            .foregroundStyle(.orange)
                            .cornerRadius(16)
                    } else {
                        Image(systemName: "slider.horizontal.3")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isEditMode)
        .animation(.easeInOut(duration: 0.2), value: editingStore)
        .animation(.easeInOut(duration: 0.2), value: isAddingNew)
    }
    
    // MARK: - Normal Chip (tap to select, long-press to enter edit mode)
    
    private func normalChip(for store: String) -> some View {
        let isSelected = selectedStore == store
        return Text(store)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(isSelected ? Color.orange : Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 1.5)
            )
            .cornerRadius(16)
            .contentShape(Rectangle())
            .onTapGesture {
                selectedStore = isSelected ? "" : store
                onStoreChanged?()
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                withAnimation {
                    isEditMode = true
                }
                startEditing(store)
            }
    }
    
    // MARK: - Editable Chip (edit mode on, tap to rename, x to delete)
    
    private func editableChip(for store: String) -> some View {
        HStack(spacing: 6) {
            Text(store)
                .font(.subheadline)
            
            // Delete button
            Button {
                deleteStore(store)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.systemGray5))
        .cornerRadius(16)
        .contentShape(Rectangle())
        .onTapGesture {
            startEditing(store)
        }
    }
    
    // MARK: - Renaming Chip (text field active + delete)
    
    private func renamingChip(for store: String) -> some View {
        HStack(spacing: 6) {
            TextField("Store name", text: $editingStoreName)
                .font(.subheadline)
                .textFieldStyle(.plain)
                .frame(minWidth: 60)
                .focused($editFieldFocused)
                .onSubmit {
                    saveEdit(for: store)
                }
            
            // Delete button
            Button {
                deleteStore(store)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.systemGray5))
        .cornerRadius(16)
    }
    
    // MARK: - Actions
    
    private func toggleEditMode() {
        if isEditMode {
            // Save any pending rename before exiting
            if let store = editingStore {
                saveEdit(for: store)
            }
            isEditMode = false
            editingStore = nil
            editingStoreName = ""
        } else {
            isAddingNew = false
            isEditMode = true
        }
    }
    
    private func startEditing(_ store: String) {
        // Save previous rename if switching to a different chip
        if let prev = editingStore, prev != store {
            saveEdit(for: prev)
        }
        editingStore = store
        editingStoreName = store
        editFieldFocused = true
    }
    
    private func saveEdit(for store: String) {
        let trimmed = editingStoreName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            editingStore = nil
            editingStoreName = ""
            return
        }
        
        if trimmed != store {
            storeStore.rename(oldName: store, newName: trimmed)
            if selectedStore == store {
                selectedStore = trimmed
            }
            onStoreChanged?()
        }
        
        editingStore = nil
        editingStoreName = ""
    }
    
    private func deleteStore(_ store: String) {
        storeStore.remove(store)
        if selectedStore == store {
            selectedStore = ""
        }
        if editingStore == store {
            editingStore = nil
            editingStoreName = ""
        }
        onStoreChanged?()
    }
    
    // MARK: - New Store Chip (inline creation pill)
    
    private func newStoreChip() -> some View {
        HStack(spacing: 6) {
            TextField("Store name", text: $newStoreName)
                .font(.subheadline)
                .textFieldStyle(.plain)
                .frame(minWidth: 60)
                .focused($newStoreFocused)
                .onSubmit {
                    saveNewStore()
                }
            
            // Cancel button
            Button {
                cancelNewStore()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.systemGray5))
        .cornerRadius(16)
    }
    
    private func saveNewStore() {
        let trimmed = newStoreName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            cancelNewStore()
            return
        }
        storeStore.add(trimmed)
        selectedStore = trimmed
        isAddingNew = false
        newStoreName = ""
        onStoreChanged?()
    }
    
    private func cancelNewStore() {
        isAddingNew = false
        newStoreName = ""
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
