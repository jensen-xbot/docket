import SwiftUI

struct CategoryPickerView: View {
    @Binding var selectedCategory: String
    private var categoryStore: CategoryStore { CategoryStore.shared }
    @State private var isAddingNew = false
    @State private var isEditMode = false
    @State private var editingCategoryId: UUID? = nil
    @State private var editingCategoryName: String = ""
    @State private var showIconColorPicker = false
    @State private var editingCategoryItem: CategoryItem? = nil
    @State private var newItemIcon: String = "tag.fill"
    @State private var newItemColor: String = "#8E8E93"
    @State private var newItemName: String = ""
    @State private var showNewIconColorPicker = false
    @FocusState private var editFieldFocused: Bool
    @FocusState private var newFieldFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            Text("Category")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // Category chips with edit toggle inline
            FlowLayout(spacing: 8) {
                ForEach(categoryStore.categories) { item in
                    if isEditMode {
                        if editingCategoryId == item.id {
                            renamingChip(for: item)
                        } else {
                            editableChip(for: item)
                        }
                    } else {
                        normalChip(for: item)
                    }
                }
                
                // Inline new category pill or "+ New" button
                if isAddingNew {
                    newCategoryChip()
                } else if !isEditMode {
                    Button {
                        isAddingNew = true
                        newItemName = ""
                        newItemIcon = "tag.fill"
                        newItemColor = "#8E8E93"
                        newFieldFocused = true
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
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundStyle(Color.accentColor)
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
        .sheet(isPresented: $showIconColorPicker) {
            if let item = editingCategoryItem {
                CategoryIconColorPickerSheet(
                    categoryItem: Binding(
                        get: { editingCategoryItem ?? item },
                        set: { newValue in
                            editingCategoryItem = newValue
                            categoryStore.update(newValue)
                        }
                    ),
                    onSave: {}
                )
            }
        }
        .sheet(isPresented: $showNewIconColorPicker) {
            CategoryIconColorPicker(
                selectedIcon: $newItemIcon,
                selectedColor: $newItemColor
            )
            .presentationDetents([.medium])
        }
        .animation(.easeInOut(duration: 0.2), value: isEditMode)
        .animation(.easeInOut(duration: 0.2), value: editingCategoryId)
        .animation(.easeInOut(duration: 0.2), value: isAddingNew)
    }
    
    // MARK: - Normal Chip (tap to select, long-press to enter edit mode)
    
    private func normalChip(for item: CategoryItem) -> some View {
        let chipColor = Color(hex: item.color) ?? .gray
        let isSelected = selectedCategory == item.name
        return HStack(spacing: 6) {
            Image(systemName: item.icon)
                .font(.caption2)
                .foregroundStyle(isSelected ? .white : chipColor)
            Text(item.name)
                .font(.subheadline)
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? chipColor : Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(chipColor, lineWidth: isSelected ? 0 : 1.5)
        )
        .cornerRadius(16)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedCategory = isSelected ? "" : item.name
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            withAnimation {
                isEditMode = true
            }
            startEditing(item)
        }
    }
    
    // MARK: - Editable Chip (edit mode on, tap to rename, x to delete)
    
    private func editableChip(for item: CategoryItem) -> some View {
        HStack(spacing: 6) {
            // Icon/color button
            Button {
                editingCategoryItem = item
                showIconColorPicker = true
            } label: {
                Image(systemName: item.icon)
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Color(hex: item.color) ?? .blue)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            Text(item.name)
                .font(.subheadline)
            
            // Delete button
            Button {
                deleteCategory(item)
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
            startEditing(item)
        }
    }
    
    // MARK: - Renaming Chip (text field active, icon/color + delete)
    
    private func renamingChip(for item: CategoryItem) -> some View {
        HStack(spacing: 6) {
            // Icon/color button
            Button {
                if editingCategoryItem == nil || editingCategoryItem?.id != item.id {
                    editingCategoryItem = item
                }
                showIconColorPicker = true
            } label: {
                let displayItem = (editingCategoryItem?.id == item.id) ? editingCategoryItem! : item
                Image(systemName: displayItem.icon)
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Color(hex: displayItem.color) ?? .blue)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            // Editable text field
            TextField("Category name", text: $editingCategoryName)
                .font(.subheadline)
                .textFieldStyle(.plain)
                .frame(minWidth: 60)
                .focused($editFieldFocused)
                .onSubmit {
                    saveEdit(for: item)
                }
            
            // Delete button
            Button {
                deleteCategory(item)
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
            if let id = editingCategoryId,
               let item = categoryStore.categories.first(where: { $0.id == id }) {
                saveEdit(for: item)
            }
            isEditMode = false
            editingCategoryId = nil
            editingCategoryName = ""
            editingCategoryItem = nil
        } else {
            isAddingNew = false
            isEditMode = true
        }
    }
    
    private func startEditing(_ item: CategoryItem) {
        // Save previous rename if switching to a different chip
        if let prevId = editingCategoryId, prevId != item.id,
           let prevItem = categoryStore.categories.first(where: { $0.id == prevId }) {
            saveEdit(for: prevItem)
        }
        editingCategoryId = item.id
        editingCategoryName = item.name
        editingCategoryItem = item
        editFieldFocused = true
    }
    
    private func saveEdit(for item: CategoryItem) {
        let trimmed = editingCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            editingCategoryId = nil
            editingCategoryName = ""
            editingCategoryItem = nil
            return
        }
        
        if trimmed != item.name {
            categoryStore.rename(oldName: item.name, newName: trimmed)
            if selectedCategory == item.name {
                selectedCategory = trimmed
            }
        }
        
        if let updated = editingCategoryItem, updated != item {
            categoryStore.update(updated)
        }
        
        editingCategoryId = nil
        editingCategoryName = ""
        editingCategoryItem = nil
    }
    
    private func deleteCategory(_ item: CategoryItem) {
        categoryStore.remove(item.name)
        if selectedCategory == item.name {
            selectedCategory = ""
        }
        if editingCategoryId == item.id {
            editingCategoryId = nil
            editingCategoryName = ""
            editingCategoryItem = nil
        }
    }
    
    // MARK: - New Category Chip (inline creation pill)
    
    private func newCategoryChip() -> some View {
        HStack(spacing: 6) {
            // Icon/color button for new item
            Button {
                showNewIconColorPicker = true
            } label: {
                Image(systemName: newItemIcon)
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Color(hex: newItemColor) ?? .gray)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            // Name text field
            TextField("Category name", text: $newItemName)
                .font(.subheadline)
                .textFieldStyle(.plain)
                .frame(minWidth: 60)
                .focused($newFieldFocused)
                .onSubmit {
                    saveNewCategory()
                }
            
            // Cancel button
            Button {
                cancelNewCategory()
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
    
    private func saveNewCategory() {
        let trimmed = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            cancelNewCategory()
            return
        }
        let newItem = CategoryItem(name: trimmed, icon: newItemIcon, color: newItemColor)
        categoryStore.addItem(newItem)
        selectedCategory = trimmed
        isAddingNew = false
        newItemName = ""
        newItemIcon = "tag.fill"
        newItemColor = "#8E8E93"
    }
    
    private func cancelNewCategory() {
        isAddingNew = false
        newItemName = ""
        newItemIcon = "tag.fill"
        newItemColor = "#8E8E93"
    }
}

// Simple flow layout for category chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                                  proposal: .unspecified)
        }
    }
    
    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }
        
        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}

#Preview {
    @Previewable @State var category = ""
    CategoryPickerView(selectedCategory: $category)
        .padding()
}
