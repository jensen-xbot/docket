import SwiftUI
import SwiftData

struct TaskRowView: View {
    @Bindable var task: Task
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: toggleCompleted) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(task.isCompleted ? .green : .priorityColor(task.priority))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "Mark as incomplete" : "Mark as complete")
            
            // Task Content
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .lineLimit(2)
                
                HStack(spacing: 6) {
                    Image(systemName: task.priority.icon)
                        .font(.caption2)
                        .foregroundStyle(.priorityColor(task.priority))
                    
                    if let dueDate = task.dueDate {
                        HStack(spacing: 2) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(task.dueDateDisplay)
                                .font(.caption)
                        }
                        .foregroundStyle(.dueDateColor(for: task))
                    }
                    
                    if let category = task.category, !category.isEmpty {
                        Text(category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .opacity(task.isCompleted ? 0.6 : 1.0)
    }
    
    private func toggleCompleted() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            task.isCompleted.toggle()
            task.completedAt = task.isCompleted ? Date() : nil
        }
    }
}

#Preview {
    List {
        TaskRowView(task: Task(title: "High priority", dueDate: Date(), priority: .high))
        TaskRowView(task: Task(title: "Completed", isCompleted: true, priority: .medium))
        TaskRowView(task: Task(title: "Overdue", dueDate: .daysFromNow(-2), priority: .high))
    }
    .modelContainer(for: Task.self, inMemory: true)
}