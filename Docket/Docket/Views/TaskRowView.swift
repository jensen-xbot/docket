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
    /// Shared binding: which task's slider is currently open (managed by TaskListView)
    @Binding var activeProgressTaskId: UUID?
    private var categoryStore: CategoryStore { CategoryStore.shared }
    
    private var isSliderVisible: Bool {
        activeProgressTaskId == task.id
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Colored left border for shared tasks (recipient) or shared-with (owner)
            if task.isShared || !sharedWithProfiles.isEmpty {
                Rectangle()
                    .fill(.blue)
                    .frame(width: 3)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    // Completion button: Progress ring when enabled, checkbox otherwise
                    if task.isProgressEnabled {
                        Button(action: handleProgressRingTap) {
                            ProgressRing(progress: effectiveProgress)
                                .contentShape(Rectangle())
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(task.isCompleted ? "Tap to undo completion" : "Tap to adjust progress")
                    } else {
                        Button(action: toggleCompleted) {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(task.isCompleted ? .green : Color.priorityColor(task.priority))
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(task.isCompleted ? "Mark as incomplete" : "Mark as complete")
                    }
                    
                    // Task Content
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(task.title)
                                .font(.body)
                                .strikethrough(task.isCompleted)
                                .foregroundStyle(task.isCompleted ? .secondary : .primary)
                                .lineLimit(2)
                            
                            Spacer()
                            
                            // Shared avatars on the title line
                            if task.isShared {
                                SharedAvatarView(
                                    currentUserProfile: currentUserProfile,
                                    sharerProfile: sharerProfile,
                                    size: 20
                                )
                            } else if !sharedWithProfiles.isEmpty {
                                SharedAvatarView(
                                    currentUserProfile: currentUserProfile,
                                    recipientProfiles: sharedWithProfiles,
                                    size: 20
                                )
                            }
                        }
                        
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
                    
                    Spacer(minLength: 0)
                    
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
                
                // Progress slider (when open) — no progress bar, just the ring + slider
                if task.isProgressEnabled && isSliderVisible {
                    ProgressSlider(progress: Binding(
                        get: { task.progressPercentage },
                        set: { newValue in
                            task.progressPercentage = newValue
                            task.lastProgressUpdate = Date()
                            task.updatedAt = Date()
                            task.syncStatus = SyncStatus.pending.rawValue
                            
                            if newValue >= 100 && !task.isCompleted {
                                task.isCompleted = true
                                task.completedAt = Date()
                            } else if newValue < 100 && task.isCompleted {
                                task.isCompleted = false
                                task.completedAt = nil
                            }
                            
                            _Concurrency.Task {
                                await NotificationManager.shared.scheduleNotification(for: task)
                                await syncEngine.pushTask(task)
                            }
                        }
                    ))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                    .onDisappear {
                        // Auto-dismiss if row scrolls off screen
                        if activeProgressTaskId == task.id {
                            activeProgressTaskId = nil
                        }
                    }
                }
            }
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
    
    private var effectiveProgress: Double {
        task.isCompleted ? 100 : task.progressPercentage
    }
    
    private func handleProgressRingTap() {
        if task.isCompleted {
            // Undo completion: reset to 0% and reopen
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                task.progressPercentage = 0
                task.isCompleted = false
                task.completedAt = nil
                task.lastProgressUpdate = Date()
                task.updatedAt = Date()
                task.syncStatus = SyncStatus.pending.rawValue
            }
            _Concurrency.Task {
                await NotificationManager.shared.scheduleNotification(for: task)
                await syncEngine.pushTask(task)
            }
        } else {
            // Toggle slider open/close
            withAnimation(.easeInOut(duration: 0.2)) {
                activeProgressTaskId = isSliderVisible ? nil : task.id
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: Task.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext
    let syncEngine = SyncEngine(modelContext: context, networkMonitor: nil)
    
    return List {
        TaskRowView(task: Task(title: "High priority", dueDate: Date(), priority: .high), syncEngine: syncEngine, activeProgressTaskId: .constant(nil))
        TaskRowView(task: Task(title: "With progress", priority: .medium, isProgressEnabled: true), syncEngine: syncEngine, activeProgressTaskId: .constant(nil))
        TaskRowView(task: Task(title: "Half done", priority: .low, progressPercentage: 50, isProgressEnabled: true), syncEngine: syncEngine, activeProgressTaskId: .constant(nil))
        TaskRowView(task: Task(title: "Completed progress", isCompleted: true, priority: .medium, progressPercentage: 100, isProgressEnabled: true), syncEngine: syncEngine, activeProgressTaskId: .constant(nil))
    }
    .modelContainer(container)
}
