import SwiftUI
import SwiftData

struct ChecklistEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \IngredientLibrary.useCount, order: .reverse) private var ingredientLibrary: [IngredientLibrary]
    @Binding var items: [ChecklistItem]
    var onSaveTemplate: (() -> Void)? = nil
    var autoFocusAdd: Bool = true
    @State private var newItemName: String = ""
    @State private var isExpanded: Bool = true
    @State private var quantityPickerItem: ChecklistItem? = nil
    @State private var quantitySelection: Int = 1
    @State private var pulsingItemId: UUID? = nil
    @State private var editMode: EditMode = .inactive
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
            
            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(suggestions) { suggestion in
                        Button {
                            newItemName = suggestion.displayName
                            addItem()
                        } label: {
                            HStack {
                                Text(suggestion.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("\(suggestion.useCount)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .cornerRadius(6)
            }
            
            // Items
            if isExpanded {
                List {
                    ForEach(sortedItems) { item in
                        ingredientRow(item)
                            .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 8))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .onMove(perform: moveItems)
                    .deleteDisabled(true)
                }
                .listStyle(.plain)
                .environment(\.editMode, $editMode)
                .frame(height: CGFloat(max(items.count, 1)) * 56)
                .scrollDisabled(true)
                
                // Save New Template button below items
                if let onSaveTemplate, !items.isEmpty {
                    Button(action: onSaveTemplate) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.subheadline)
                                .foregroundStyle(.tint)
                            Text("Save as New Template")
                                .font(.subheadline)
                                .foregroundStyle(.tint)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
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
            if autoFocusAdd {
                addItemFocused = true
            }
            seedIngredientLibraryIfNeeded()
        }
        .sheet(item: $quantityPickerItem) { item in
            NavigationStack {
                VStack {
                    Picker("Quantity", selection: $quantitySelection) {
                        ForEach(1...99, id: \.self) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                }
                .navigationTitle(item.name)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { quantityPickerItem = nil }
                    }
                }
                .onAppear {
                    quantitySelection = max(item.quantity, 1)
                }
                .onChange(of: quantitySelection) {
                    updateQuantity(for: item.id, to: quantitySelection)
                }
            }
            .presentationDetents([.height(280)])
        }
    }
    
    private var sortedItems: [ChecklistItem] {
        items.sorted {
            if $0.isChecked != $1.isChecked {
                return !$0.isChecked
            }
            return $0.sortOrder < $1.sortOrder
        }
    }
    
    
    
    private var suggestions: [IngredientLibrary] {
        let normalizedInput = normalizeIngredient(newItemName)
        guard !normalizedInput.isEmpty else { return [] }
        let prefixMatches = ingredientLibrary.filter { $0.name.hasPrefix(normalizedInput) }
        if !prefixMatches.isEmpty {
            return Array(prefixMatches.prefix(6))
        }
        let fuzzyMatches = ingredientLibrary
            .map { (item: $0, distance: levenshteinDistance(normalizedInput, $0.name)) }
            .filter { $0.distance <= 2 }
            .sorted { $0.distance < $1.distance }
            .map(\.item)
        return Array(fuzzyMatches.prefix(6))
    }

    
    private func addItem() {
        let trimmed = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let displayName = recordIngredientUsage(for: trimmed)
        // Shift all existing unchecked items down, insert new item at top
        for i in items.indices where !items[i].isChecked {
            items[i].sortOrder += 1
        }
        items.append(ChecklistItem(id: UUID(), name: displayName, isChecked: false, sortOrder: 0))
        newItemName = ""
        addItemFocused = true
        if !isExpanded {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded = true
            }
        }
    }
    
    private func toggle(_ item: ChecklistItem) {
        guard let index = sortedItems.firstIndex(where: { $0.id == item.id }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            var ordered = sortedItems
            var updated = ordered.remove(at: index)
            updated.isChecked.toggle()
            
            if updated.isChecked {
                let insertIndex = ordered.firstIndex(where: { $0.isChecked }) ?? ordered.count
                ordered.insert(updated, at: insertIndex)
            } else {
                let lastUncheckedIndex = ordered.lastIndex(where: { !$0.isChecked }) ?? -1
                ordered.insert(updated, at: lastUncheckedIndex + 1)
            }
            
            items = ordered.enumerated().map { offset, element in
                var normalized = element
                normalized.sortOrder = offset
                return normalized
            }
        }
    }
    
    private func remove(_ item: ChecklistItem) {
        withAnimation(.easeInOut(duration: 0.2)) {
            items.removeAll { $0.id == item.id }
            normalizeOrder()
        }
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        var reordered = sortedItems
        reordered.move(fromOffsets: source, toOffset: destination)
        items = reordered.enumerated().map { offset, element in
            var updated = element
            updated.sortOrder = offset
            return updated
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        let sorted = sortedItems
        let idsToRemove = offsets.map { sorted[$0].id }
        withAnimation {
            items.removeAll { idsToRemove.contains($0.id) }
            normalizeOrder()
        }
    }
    
    
    private func incrementQuantity(for item: ChecklistItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let current = max(items[index].quantity, 1)
        items[index].quantity = current == 1 ? 2 : current + 1
    }
    
    private func decrementQuantity(for item: ChecklistItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let current = max(items[index].quantity, 1)
        items[index].quantity = max(1, current - 1)
    }
    
    private func updateQuantity(for id: UUID, to value: Int) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].quantity = max(value, 1)
    }
    
    private func toggleStar(for item: ChecklistItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isStarred.toggle()
        if items[index].isStarred {
            pulsingItemId = item.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                pulsingItemId = nil
            }
        }
    }
    
    private func ingredientRow(_ item: ChecklistItem) -> some View {
        HStack(spacing: 8) {
            // Checkbox
            Button(action: { toggle(item) }) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isChecked ? .green : .secondary)
            }
            .buttonStyle(.plain)
            
            // Name (tap to toggle star)
            Text(item.name)
                .foregroundStyle(item.isChecked ? .secondary : (item.isStarred ? Color.red : .primary))
                .strikethrough(item.isChecked)
                .scaleEffect(pulsingItemId == item.id ? 1.05 : 1.0)
                .animation(
                    pulsingItemId == item.id
                        ? .easeInOut(duration: 0.3).repeatCount(2, autoreverses: true)
                        : .default,
                    value: pulsingItemId
                )
                .onTapGesture {
                    toggleStar(for: item)
                }
            
            // Heart
            Button(action: { toggleStar(for: item) }) {
                Image(systemName: item.isStarred ? "heart.fill" : "heart")
                    .font(.subheadline)
                    .foregroundStyle(item.isStarred ? .red : Color(.systemGray4))
            }
            .buttonStyle(.plain)
            
            // Qty badge
            if !item.isChecked, item.quantity > 1 {
                Button {
                    quantityPickerItem = item
                } label: {
                    Text("x\(item.quantity)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            // Minus
            Button(action: { decrementQuantity(for: item) }) {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Color(.systemGray5))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(item.isChecked || item.quantity <= 1)
            
            // Plus
            Button(action: { incrementQuantity(for: item) }) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Color(.systemGray5))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(item.isChecked)
            
            // Delete
            Button(action: { remove(item) }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.red.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .cornerRadius(6)
        .contentShape(Rectangle())
    }

    private func seedIngredientLibraryIfNeeded() {
        guard ingredientLibrary.isEmpty else { return }
        for seed in IngredientSeeds.common {
            let normalized = normalizeIngredient(seed)
            let display = seed.capitalized
            let ingredient = IngredientLibrary(
                name: normalized,
                displayName: display,
                useCount: 0,
                syncStatus: .pending
            )
            modelContext.insert(ingredient)
        }
    }
    
    private func recordIngredientUsage(for input: String) -> String {
        let normalized = normalizeIngredient(input)
        guard !normalized.isEmpty else { return input }
        
        if let match = bestMatch(for: normalized) {
            match.useCount += 1
            match.updatedAt = Date()
            match.syncStatus = SyncStatus.pending.rawValue
            return match.displayName
        }
        
        let ingredient = IngredientLibrary(
            name: normalized,
            displayName: input,
            useCount: 1,
            syncStatus: .pending
        )
        modelContext.insert(ingredient)
        return ingredient.displayName
    }
    
    private func bestMatch(for normalized: String) -> IngredientLibrary? {
        if let exact = ingredientLibrary.first(where: { $0.name == normalized }) {
            return exact
        }
        let candidates = ingredientLibrary
            .map { (item: $0, distance: levenshteinDistance(normalized, $0.name)) }
            .filter { $0.distance <= 2 }
            .sorted { $0.distance < $1.distance }
        return candidates.first?.item
    }
    
    private func normalizeIngredient(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
    
    private func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        let lhsArray = Array(lhs)
        let rhsArray = Array(rhs)
        var dist = Array(repeating: Array(repeating: 0, count: rhsArray.count + 1), count: lhsArray.count + 1)
        
        for i in 0...lhsArray.count { dist[i][0] = i }
        for j in 0...rhsArray.count { dist[0][j] = j }
        
        for i in 1...lhsArray.count {
            for j in 1...rhsArray.count {
                if lhsArray[i - 1] == rhsArray[j - 1] {
                    dist[i][j] = dist[i - 1][j - 1]
                } else {
                    dist[i][j] = min(
                        dist[i - 1][j] + 1,
                        dist[i][j - 1] + 1,
                        dist[i - 1][j - 1] + 1
                    )
                }
            }
        }
        return dist[lhsArray.count][rhsArray.count]
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
            ChecklistItem(id: UUID(), name: "Milk", isChecked: false, sortOrder: 0, quantity: 1),
            ChecklistItem(id: UUID(), name: "Cheddar", isChecked: true, sortOrder: 1, quantity: 1),
            ChecklistItem(id: UUID(), name: "Eggs", isChecked: false, sortOrder: 2, quantity: 2),
            ChecklistItem(id: UUID(), name: "Bread", isChecked: false, sortOrder: 3, quantity: 1)
        ]))
        .padding()
    }
}
