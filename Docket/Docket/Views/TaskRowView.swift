import SwiftUI
import SwiftData
import _Concurrency

struct TaskRowView: View {
    @Bindable var task: Task
    var syncEngine: SyncEngine
    var onShare: (() -> Void)? = nil
    var currentUserProfile: UserProfile?
    var sharerProfile: UserProfile?
    /// For owner-side: recipients this task is shared with
    var sharedWithProfiles: [UserProfile] = []
    private var categoryStore: CategoryStore { CategoryStore.shared }
    
    var body: some View {
        HStack(spacing: 0) {
            // Colored left border for shared tasks (recipient) or shared-with (owner)
            if task.isShared || !sharedWithProfiles.isEmpty {
                Rectangle()
                    .fill(.blue)
                    .frame(width: 3)
            }
            
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
                        // Priority arrow
                        Image(systemName: task.priority.icon)
                            .font(.caption2)
                            .foregroundStyle(Color.priorityColor(task.priority))
                        
                        // Category icon + label (right of priority)
                        if let category = task.category, !category.isEmpty {
                            if let categoryItem = categoryStore.find(byName: category) {
                                let catColor = Color(hex: categoryItem.color) ?? .gray
                                HStack(spacing: 4) {
                                    Image(systemName: categoryItem.icon)
                                        .font(.caption2)
                                        .foregroundStyle(catColor)
                                        .padding(4)
                                        .background(
                                            Circle()
                                                .stroke(catColor, lineWidth: 1.5)
                                        )
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
                        
                        // Due date in circle (right of category)
                        if let dueDate = task.dueDate {
                            let dateColor = Color.dueDateColor(for: task)
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.caption2)
                                    .foregroundStyle(dateColor)
                                    .padding(4)
                                    .background(
                                        Circle()
                                            .stroke(dateColor, lineWidth: 1.5)
                                    )
                                Text(dueDate.formattedDueDate)
                                    .font(.caption)
                                    .foregroundStyle(dateColor)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Shared avatar overlay (recipient: sharer; owner: people shared with)
                if task.isShared {
                    SharedAvatarView(
                        currentUserProfile: currentUserProfile,
                        sharerProfile: sharerProfile
                    )
                } else if !sharedWithProfiles.isEmpty {
                    SharedAvatarView(recipientProfiles: sharedWithProfiles)
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
            .padding(.leading, (task.isShared || !sharedWithProfiles.isEmpty) ? 8 : 0)
        }
        .contentShape(Rectangle())
        .opacity(task.isCompleted ? 0.6 : 1.0)
        .contextMenu {
            Button {
                togglePinned()
            } label: {
                Label(task.isPinned ? "Unpin" : "Pin", systemImage: task.isPinned ? "pin.slash" : "pin")
            }
            
            if task.isShared {
                Button(role: .destructive) {
                    removeSharedTask()
                } label: {
                    Label("Remove from my list", systemImage: "trash")
                }
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
            await syncEngine.pushTask(task)
        }
    }
    
    private func togglePinned() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            task.isPinned.toggle()
            task.updatedAt = Date()
            task.syncStatus = SyncStatus.pending.rawValue
        }
        _Concurrency.Task {
            await syncEngine.pushTask(task)
        }
    }
    
    private func removeSharedTask() {
        _Concurrency.Task {
            await syncEngine.removeSharedTask(taskId: task.id)
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: Task.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext
    let syncEngine = SyncEngine(modelContext: context, networkMonitor: nil)
    
    return List {
        TaskRowView(task: Task(title: "High priority", dueDate: Date(), priority: .high), syncEngine: syncEngine)
        TaskRowView(task: Task(title: "Completed", isCompleted: true, priority: .medium), syncEngine: syncEngine)
        TaskRowView(task: Task(title: "Overdue", dueDate: .daysFromNow(-2), priority: .high), syncEngine: syncEngine)
    }
    .modelContainer(container)
}