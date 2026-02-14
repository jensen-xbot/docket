import SwiftUI
import SwiftData
import _Concurrency

/// Today View - Shows tasks organized by urgency
/// Sections: Overdue, Due Today, Later Today, No Due Date
struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncEngine.self) private var syncEngine
    @Query(sort: \Task.createdAt, order: .reverse) private var allTasks: [Task]
    
    @State private var showingCommandBarExpanded = false
    @State private var conversationMessages: [ConversationMessage] = []
    @State private var isProcessingConversation = false
    
    // MARK: - Task Grouping
    
    private var overdueTasks: [Task] {
        allTasks.filter { task in
            guard let dueDate = task.dueDate, !task.isCompleted else { return false }
            return dueDate < Calendar.current.startOfDay(for: Date())
        }.sorted {
            if let d0 = $0.dueDate, let d1 = $1.dueDate {
                return d0 < d1
            }
            return false
        }
    }
    
    private var dueTodayTasks: [Task] {
        allTasks.filter { task in
            guard let dueDate = task.dueDate, !task.isCompleted else { return false }
            return Calendar.current.isDateInToday(dueDate) && !hasTime(dueDate)
        }.sorted {
            if let d0 = $0.dueDate, let d1 = $1.dueDate {
                return d0 < d1
            }
            return false
        }
    }
    
    private var laterTodayTasks: [Task] {
        allTasks.filter { task in
            guard let dueDate = task.dueDate, !task.isCompleted, task.hasTime else { return false }
            return Calendar.current.isDateInToday(dueDate)
        }.sorted {
            if let d0 = $0.dueDate, let d1 = $1.dueDate {
                return d0 < d1
            }
            return false
        }
    }
    
    private var noDueDateTasks: [Task] {
        allTasks.filter { task in
            task.dueDate == nil && !task.isCompleted
        }.sorted {
            $0.createdAt > $1.createdAt
        }
    }
    
    private func hasTime(_ date: Date) -> Bool {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return components.hour != 0 || components.minute != 0
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                mainContent
            }
            .navigationTitle("Today")
            .refreshable {
                await syncEngine.pullRemoteChanges()
            }
            .safeAreaInset(edge: .bottom) {
                CommandBarView(
                    text: .constant(""),
                    onSubmit: { text, completion in
                        handleCommandSubmit(text, completion: completion)
                    },
                    onVoiceTap: {
                        // Voice mode activation
                    }
                )
            }
            .overlay {
                if showingCommandBarExpanded {
                    CommandBarExpanded(
                        isExpanded: $showingCommandBarExpanded,
                        messages: $conversationMessages,
                        inputText: .constant(""),
                        isProcessing: isProcessingConversation,
                        onSend: { _ in },
                        onVoiceTap: {},
                        onClose: {
                            showingCommandBarExpanded = false
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Views
    
    @ViewBuilder
    private var mainContent: some View {
        if allTasks.isEmpty {
            emptyState
        } else {
            taskList
        }
    }
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing Due Today", systemImage: "calendar.badge.checkmark")
        } description: {
            Text("You're all caught up! Enjoy your day.")
        }
    }
    
    private var taskList: some View {
        List {
            // Overdue Section
            if !overdueTasks.isEmpty {
                Section {
                    ForEach(overdueTasks) { task in
                        TaskRowView(
                            task: task,
                            syncEngine: syncEngine,
                            onShare: {},
                            currentUserProfile: nil,
                            sharerProfile: nil,
                            sharedWithProfiles: [],
                            activeProgressTaskId: .constant(nil)
                        )
                    }
                } header: {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Overdue")
                    }
                    .font(.headline)
                    .foregroundStyle(.red)
                }
            }
            
            // Due Today Section
            if !dueTodayTasks.isEmpty {
                Section {
                    ForEach(dueTodayTasks) { task in
                        TaskRowView(
                            task: task,
                            syncEngine: syncEngine,
                            onShare: {},
                            currentUserProfile: nil,
                            sharerProfile: nil,
                            sharedWithProfiles: [],
                            activeProgressTaskId: .constant(nil)
                        )
                    }
                } header: {
                    HStack {
                        Image(systemName: "calendar")
                        Text("Due Today")
                    }
                    .font(.headline)
                    .foregroundStyle(.primary)
                }
            }
            
            // Later Today Section (with time)
            if !laterTodayTasks.isEmpty {
                Section {
                    ForEach(laterTodayTasks) { task in
                        TaskRowView(
                            task: task,
                            syncEngine: syncEngine,
                            onShare: {},
                            currentUserProfile: nil,
                            sharerProfile: nil,
                            sharedWithProfiles: [],
                            activeProgressTaskId: .constant(nil)
                        )
                    }
                } header: {
                    HStack {
                        Image(systemName: "clock")
                        Text("Later Today")
                    }
                    .font(.headline)
                    .foregroundStyle(.primary)
                }
            }
            
            // No Due Date Section (collapsed by default in future)
            if !noDueDateTasks.isEmpty {
                Section {
                    ForEach(noDueDateTasks) { task in
                        TaskRowView(
                            task: task,
                            syncEngine: syncEngine,
                            onShare: {},
                            currentUserProfile: nil,
                            sharerProfile: nil,
                            sharedWithProfiles: [],
                            activeProgressTaskId: .constant(nil)
                        )
                    }
                } header: {
                    HStack {
                        Image(systemName: "infinity")
                        Text("No Due Date")
                    }
                    .font(.headline)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Handlers
    
    private func handleCommandSubmit(_ text: String, completion: @escaping (ParseResponse) -> Void) {
        // TODO: Implement confidence flow for TodayView
        let response = ParseResponse(
            type: "question",
            text: "Today view task creation not yet implemented.",
            tasks: nil,
            taskId: nil,
            changes: nil,
            summary: nil,
            confidence: .low
        )
        completion(response)
    }
}

// MARK: - Preview

#Preview("Today View") {
    TodayView()
        .modelContainer(for: Task.self, inMemory: true)
}
