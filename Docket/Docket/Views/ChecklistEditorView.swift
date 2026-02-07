import SwiftUI

struct ChecklistEditorView: View {
    @Binding var items: [ChecklistItem]
    @State private var newItemName: String = ""
    @State private var isExpanded: Bool = true
    @State private var draggingItem: ChecklistItem? = nil
    @FocusState private var addItemFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with expand/collapse toggle
            HStack {
                Text("Items (\(items.count))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if !items.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up.circle" : "chevron.down.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Add item row (always visible)
            HStack(spacing: 8) {
                TextField("Add item...", text: $newItemName)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled()
                    .focused($addItemFocused)
                    .onSubmit { addItem() }
                Button(action: addItem) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
                .disabled(newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            // Items
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(Array(sortedItems.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 10) {
                            // Drag handle
                            Image(systemName: "line.3.horizontal")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            
                            Button(action: { toggle(item) }) {
                                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.isChecked ? .green : .secondary)
                            }
                            .buttonStyle(.plain)
                            
                            Text(item.name)
                                .foregroundStyle(item.isChecked ? .secondary : .primary)
                                .strikethrough(item.isChecked)
                            
                            Spacer()
                            
                            Button(action: { remove(item) }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(Color.red.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .opacity(draggingItem?.id == item.id ? 0.4 : 1)
                        .draggable(item.id.uuidString) {
                            // Drag preview
                            HStack(spacing: 8) {
                                Image(systemName: "line.3.horizontal")
                                    .font(.caption)
                                Text(item.name)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.regularMaterial)
                            .cornerRadius(8)
                            .onAppear { draggingItem = item }
                        }
                        .dropDestination(for: String.self) { droppedItems, _ in
                            guard let droppedId = droppedItems.first,
                                  let fromUUID = UUID(uuidString: droppedId),
                                  let fromIndex = sortedItems.firstIndex(where: { $0.id == fromUUID }),
                                  let toIndex = sortedItems.firstIndex(where: { $0.id == item.id }),
                                  fromIndex != toIndex else { return false }
                            
                            var ordered = sortedItems
                            let moved = ordered.remove(at: fromIndex)
                            ordered.insert(moved, at: toIndex)
                            items = ordered.enumerated().map { offset, element in
                                var updated = element
                                updated.sortOrder = offset
                                return updated
                            }
                            draggingItem = nil
                            return true
                        }
                        
                        if index < sortedItems.count - 1 {
                            Divider()
                                .padding(.leading, 28)
                        }
                    }
                }
            } else {
                // Collapsed summary
                Text(sortedItems.prefix(3).map { $0.name }.joined(separator: ", ")
                     + (items.count > 3 ? " +\(items.count - 3) more" : ""))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded = true
                        }
                    }
            }
        }
        .onAppear {
            addItemFocused = true
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
        addItemFocused = true
        if !isExpanded {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded = true
            }
        }
    }
    
    private func toggle(_ item: ChecklistItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isChecked.toggle()
    }
    
    private func remove(_ item: ChecklistItem) {
        withAnimation(.easeInOut(duration: 0.2)) {
            items.removeAll { $0.id == item.id }
            normalizeOrder()
        }
    }
    
    private func normalizeOrder() {
        items = sortedItems.enumerated().map { offset, element in
            var updated = element
            updated.sortOrder = offset
            return updated
        }
    }
}

#Preview {
    ScrollView {
        ChecklistEditorView(items: .constant([
            ChecklistItem(id: UUID(), name: "Milk", isChecked: false, sortOrder: 0),
            ChecklistItem(id: UUID(), name: "Cheddar", isChecked: true, sortOrder: 1),
            ChecklistItem(id: UUID(), name: "Eggs", isChecked: false, sortOrder: 2),
            ChecklistItem(id: UUID(), name: "Bread", isChecked: false, sortOrder: 3)
        ]))
        .padding()
    }
}
