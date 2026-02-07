import SwiftUI

struct ChecklistEditorView: View {
    @Binding var items: [ChecklistItem]
    @State private var newItemName: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Items")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                TextField("Add item...", text: $newItemName)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled()
                Button(action: addItem) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
            }
            
            VStack(spacing: 8) {
                ForEach(sortedItems) { item in
                    HStack(spacing: 10) {
                        Button(action: { toggle(item) }) {
                            Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.isChecked ? .green : .secondary)
                        }
                        .buttonStyle(.plain)
                        
                        Text(item.name)
                            .foregroundStyle(item.isChecked ? .secondary : .primary)
                            .strikethrough(item.isChecked)
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Button(action: { move(item, direction: -1) }) {
                                Image(systemName: "chevron.up")
                            }
                            .buttonStyle(.plain)
                            .disabled(isFirst(item))
                            
                            Button(action: { move(item, direction: 1) }) {
                                Image(systemName: "chevron.down")
                            }
                            .buttonStyle(.plain)
                            .disabled(isLast(item))
                            
                            Button(role: .destructive, action: { remove(item) }) {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    private var sortedItems: [ChecklistItem] {
        items.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    private func addItem() {
        let trimmed = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let nextOrder = (items.map { $0.sortOrder }.max() ?? -1) + 1
        items.append(ChecklistItem(id: UUID(), name: trimmed, isChecked: false, sortOrder: nextOrder))
        newItemName = ""
    }
    
    private func toggle(_ item: ChecklistItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isChecked.toggle()
    }
    
    private func remove(_ item: ChecklistItem) {
        items.removeAll { $0.id == item.id }
        normalizeOrder()
    }
    
    private func move(_ item: ChecklistItem, direction: Int) {
        let ordered = sortedItems
        guard let index = ordered.firstIndex(where: { $0.id == item.id }) else { return }
        let newIndex = index + direction
        guard newIndex >= 0 && newIndex < ordered.count else { return }
        
        var mutable = ordered
        let moved = mutable.remove(at: index)
        mutable.insert(moved, at: newIndex)
        items = mutable.enumerated().map { offset, element in
            var updated = element
            updated.sortOrder = offset
            return updated
        }
    }
    
    private func normalizeOrder() {
        items = sortedItems.enumerated().map { offset, element in
            var updated = element
            updated.sortOrder = offset
            return updated
        }
    }
    
    private func isFirst(_ item: ChecklistItem) -> Bool {
        guard let first = sortedItems.first else { return false }
        return first.id == item.id
    }
    
    private func isLast(_ item: ChecklistItem) -> Bool {
        guard let last = sortedItems.last else { return false }
        return last.id == item.id
    }
}

#Preview {
    ChecklistEditorView(items: .constant([
        ChecklistItem(id: UUID(), name: "Milk", isChecked: false, sortOrder: 0),
        ChecklistItem(id: UUID(), name: "Cheddar", isChecked: true, sortOrder: 1)
    ]))
    .padding()
}
