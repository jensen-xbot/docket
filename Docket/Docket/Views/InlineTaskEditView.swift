import SwiftUI
import SwiftData

/// Inline task edit view for medium confidence confirmation flow
/// Compact card design that expands inline for quick edits
struct InlineTaskEditView: View {
    @Binding var task: ParsedTask
    var onSave: () -> Void
    var onCancel: () -> Void
    
    @State private var editedTitle: String = ""
    @State private var editedDueDate: Date?
    @State private var editedHasTime: Bool = false
    @State private var editedPriority: Priority = .medium
    @State private var editedCategory: String? = nil
    @State private var showDatePicker: Bool = false
    @State private var showTimePicker: Bool = false
    
    @FocusState private var titleFocused: Bool
    
    private var categoryStore: CategoryStore { CategoryStore.shared }
    
    private var isValid: Bool {
        !editedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text("Edit Task")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Title field
                TextField("Task title", text: $editedTitle, axis: .vertical)
                    .font(.system(size: 18, weight: .semibold))
                    .focused($titleFocused)
                    .lineLimit(1...3)
                
                // Due date row
                HStack(spacing: 12) {
                    Button(action: { showDatePicker.toggle() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 14))
                            Text(dateDisplayText)
                                .font(.system(size: 15))
                        }
                        .foregroundStyle(editedDueDate != nil ? .primary : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    if editedDueDate != nil {
                        Button(action: { showTimePicker.toggle() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .font(.system(size: 14))
                                Text(timeDisplayText)
                                    .font(.system(size: 15))
                            }
                            .foregroundStyle(editedHasTime ? .primary : .secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            editedDueDate = nil
                            editedHasTime = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Date picker (inline)
                if showDatePicker {
                    DatePicker(
                        "Due date",
                        selection: Binding(
                            get: { editedDueDate ?? Date() },
                            set: { editedDueDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .frame(maxHeight: 300)
                }
                
                // Time picker (inline)
                if showTimePicker && editedDueDate != nil {
                    DatePicker(
                        "Time",
                        selection: Binding(
                            get: {
                                if let due = editedDueDate {
                                    return due
                                }
                                return Date()
                            },
                            set: { newDate in
                                if var due = editedDueDate {
                                    let calendar = Calendar.current
                                    let timeComponents = calendar.dateComponents([.hour, .minute], from: newDate)
                                    due = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                                       minute: timeComponents.minute ?? 0,
                                                       second: 0,
                                                       of: due) ?? due
                                    editedDueDate = due
                                    editedHasTime = true
                                }
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .frame(maxHeight: 150)
                }
                
                // Priority picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Priority")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Picker("Priority", selection: $editedPriority) {
                        ForEach(Priority.allCases, id: \.self) { p in
                            HStack(spacing: 4) {
                                Image(systemName: priorityIcon(for: p))
                                Text(p.displayName)
                            }
                            .tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Category chips
                VStack(alignment: .leading, spacing: 6) {
                    Text("Category")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    FlowLayout(spacing: 8) {
                        // "None" option
                        CategoryChip(
                            name: "None",
                            color: .gray,
                            isSelected: editedCategory == nil
                        ) {
                            editedCategory = nil
                        }
                        
                        ForEach(categoryStore.categories) { item in
                            let isSelected = editedCategory == item.name
                            CategoryChip(
                                name: item.name,
                                color: Color(hex: item.color) ?? .gray,
                                isSelected: isSelected
                            ) {
                                editedCategory = item.name
                            }
                        }
                    }
                }
                
                // Action buttons
                HStack(spacing: 12) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                    
                    Button(action: saveChanges) {
                        Text("Save")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(!isValid)
                }
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
        }
        .onAppear {
            // Initialize from task
            editedTitle = task.title
            editedDueDate = task.dueDate
            editedHasTime = task.hasTime
            editedPriority = parsePriority(task.priority)
            editedCategory = task.category
            
            // Auto-focus title
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                titleFocused = true
            }
        }
    }
    
    // MARK: - Helpers
    
    private var dateDisplayText: String {
        guard let date = editedDueDate else { return "Add date" }
        
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
    
    private var timeDisplayText: String {
        guard editedHasTime, let date = editedDueDate else { return "Add time" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    private func parsePriority(_ value: String) -> Priority {
        switch value.lowercased() {
        case "low": return .low
        case "high": return .high
        default: return .medium
        }
    }
    
    private func priorityIcon(for priority: Priority) -> String {
        switch priority {
        case .low: return "arrow.down"
        case .medium: return "minus"
        case .high: return "arrow.up"
        }
    }
    
    private func saveChanges() {
        // Update the bound task
        task.title = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        task.dueDate = editedDueDate
        task.hasTime = editedHasTime
        task.priority = priorityString(editedPriority)
        task.category = editedCategory
        
        onSave()
    }
    
    private func priorityString(_ priority: Priority) -> String {
        switch priority {
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        }
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let name: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                }
                Text(name)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
            }
            .foregroundStyle(isSelected ? .white : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? color : color.opacity(0.15))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Flow Layout (simplified for category chips)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            
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
            }
            
            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

// MARK: - Preview

#Preview("Inline Task Edit") {
    struct PreviewWrapper: View {
        @State var task = ParsedTask(
            id: UUID(),
            title: "Buy groceries for dinner",
            dueDate: Date().addingTimeInterval(86400),
            hasTime: false,
            priority: "medium",
            category: "Shopping"
        )
        
        var body: some View {
            VStack {
                Spacer()
                InlineTaskEditView(
                    task: $task,
                    onSave: { print("Saved: \(task.title)") },
                    onCancel: { print("Cancelled") }
                )
            }
            .background(Color(.systemGroupedBackground))
        }
    }
    
    return PreviewWrapper()
}
