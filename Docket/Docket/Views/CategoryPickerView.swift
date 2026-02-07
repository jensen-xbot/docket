import SwiftUI

struct CategoryPickerView: View {
    @Binding var selectedCategory: String
    @State private var categoryStore = CategoryStore()
    @State private var newCategory = ""
    @State private var isAddingNew = false
    @FocusState private var newCategoryFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // Existing categories as chips
            FlowLayout(spacing: 8) {
                ForEach(categoryStore.categories, id: \.self) { cat in
                    Button {
                        if selectedCategory == cat {
                            selectedCategory = ""
                        } else {
                            selectedCategory = cat
                        }
                    } label: {
                        Text(cat)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedCategory == cat ? Color.accentColor : Color(.systemGray6))
                            .foregroundStyle(selectedCategory == cat ? Color.white : Color.primary)
                            .cornerRadius(16)
                    }
                }
                
                // Add new button
                Button {
                    isAddingNew = true
                    newCategoryFocused = true
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
            
            // Add new category input
            if isAddingNew {
                HStack(spacing: 8) {
                    TextField("New category", text: $newCategory)
                        .font(.subheadline)
                        .focused($newCategoryFocused)
                        .onSubmit { addCategory() }
                    
                    Button(action: addCategory) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                    .disabled(newCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    Button {
                        isAddingNew = false
                        newCategory = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            }
        }
    }
    
    private func addCategory() {
        let trimmed = newCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        categoryStore.add(trimmed)
        selectedCategory = trimmed
        newCategory = ""
        isAddingNew = false
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
