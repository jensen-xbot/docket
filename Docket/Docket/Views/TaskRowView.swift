import SwiftUI
import SwiftData
import _Concurrency

struct TaskRowView: View {
    @Bindable var task: Task
    var onShare: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: toggleCompleted) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(task.isCompleted ? .green : Color.priorityColor(task.priority))
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
                        .foregroundStyle(Color.priorityColor(task.priority))
                    
                    if let dueDate = task.dueDate {
                        HStack(spacing: 2) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(dueDate.formattedDueDate)
                                .font(.caption)
                        }
                        .foregroundStyle(Color.dueDateColor(for: task))
                    }
                    
                    if let category = task.category, !category.isEmpty {
                        let categoryColor = Color.categoryColor(category)
                        if let categoryColor = categoryColor {
                            HStack(spacing: 4) {
                                Image(systemName: "cart.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background(categoryColor)
                                    .clipShape(Circle())
                                Text(category)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text(category)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            if task.isShared {
                Image(systemName: "person.2.fill")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
            
            if let onShare = onShare {
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Button(action: togglePinned) {
                Image(systemName: task.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(task.isPinned ? .orange : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .opacity(task.isCompleted ? 0.6 : 1.0)
        .contextMenu {
            Button {
                togglePinned()
            } label: {
                Label(task.isPinned ? "Unpin" : "Pin", systemImage: task.isPinned ? "pin.slash" : "pin")
            }
        }
    }
    
    private func toggleCompleted() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            task.isCompleted.toggle()
            task.completedAt = task.isCompleted ? Date() : nil
            task.updatedAt = Date()
            task.syncStatus = SyncStatus.pending.rawValue
        }
        _Concurrency.Task {
            await NotificationManager.shared.scheduleNotification(for: task)
        }
    }
    
    private func togglePinned() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            task.isPinned.toggle()
            task.updatedAt = Date()
            task.syncStatus = SyncStatus.pending.rawValue
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