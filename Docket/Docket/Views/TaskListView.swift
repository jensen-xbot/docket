import SwiftUI
import SwiftData
import _Concurrency

enum TaskFilter: String, CaseIterable {
    case all = "All"
    case active = "Active"
    case completed = "Completed"
}

@Observable
class TaskListViewModel {
    var selectedFilter: TaskFilter = .all
    var searchText: String = ""
    var selectedPriority: Priority?
    var selectedCategory: String?
    
    func filteredTasks(from tasks: [Task]) -> [Task] {
        var result = tasks
        
        switch selectedFilter {
        case .all: break
        case .active: result = result.filter { !$0.isCompleted }
        case .completed: result = result.filter { $0.isCompleted }
        }
        
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        
        if let priority = selectedPriority {
            result = result.filter { $0.priority == priority }
        }
        
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        
        return result.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }
            if $0.priority.rawValue != $1.priority.rawValue { return $0.priority.rawValue > $1.priority.rawValue }
            if let d0 = $0.dueDate, let d1 = $1.dueDate { return d0 < d1 }
            return $0.dueDate != nil && $1.dueDate == nil
        }
    }
}

struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Task.createdAt, order: .reverse) private var allTasks: [Task]
    
    var authManager: AuthManager?
    
    @State private var viewModel = TaskListViewModel()
    @State private var showingAddTask = false
    @State private var taskToEdit: Task?
    @State private var taskToShare: Task?
    @State private var syncEngine: SyncEngine?
    @State private var editMode: EditMode = .inactive
    
    private var filteredTasks: [Task] {
        viewModel.filteredTasks(from: allTasks)
    }

    @State private var categoryStore = CategoryStore()
    
    private var hasActiveFilters: Bool {
        viewModel.selectedFilter != .all ||
        viewModel.selectedPriority != nil ||
        viewModel.selectedCategory != nil ||
        !viewModel.searchText.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if allTasks.isEmpty {
                    EmptyListView {
                        showingAddTask = true
                    }
                } else if filteredTasks.isEmpty {
                    ContentUnavailableView {
                        Label("No Matching Tasks", systemImage: "line.3.horizontal.decrease.circle")
                    } description: {
                        Text("Try adjusting your filters or search.")
                    }
                } else {
                    taskList
                }
            }
            .navigationTitle("Docket")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    filterMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        if let syncEngine = syncEngine, syncEngine.isSyncing {
                            ProgressView()
                                .scaleEffect(0.8)
                        }

                        Button(editMode == .active ? "Done" : "Reorder") {
                            editMode = editMode == .active ? .inactive : .active
                        }

                        // Profile
                        if let authManager = authManager {
                            NavigationLink {
                                ProfileView(authManager: authManager)
                            } label: {
                                Image(systemName: "person.circle")
                            }
                        }

                        // Show + only when tasks exist to avoid mis-taps on empty state
                        if !allTasks.isEmpty {
                            Button(action: { showingAddTask = true }) {
                                Image(systemName: "plus")
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
            .refreshable {
                await syncAll()
            }
            .onAppear {
                if syncEngine == nil {
                    syncEngine = SyncEngine(modelContext: modelContext)
                }
                _Concurrency.Task {
                    await syncAll()
                }
            }
            .fullScreenCover(isPresented: $showingAddTask) {
                AddTaskView()
            }
            .fullScreenCover(item: $taskToEdit) { task in
                EditTaskView(task: task)
            }
            .sheet(item: $taskToShare) { task in
                ShareTaskView(task: task)
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search tasks")
    }
    
    private var filterMenu: some View {
        Menu {
            Picker("Filter", selection: $viewModel.selectedFilter) {
                ForEach(TaskFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            Divider()
            Menu("Priority") {
                Button {
                    viewModel.selectedPriority = nil
                } label: {
                    if viewModel.selectedPriority == nil {
                        Label("All", systemImage: "checkmark")
                    } else {
                        Text("All")
                    }
                }
                ForEach(Priority.allCases, id: \.self) { p in
                    Button {
                        viewModel.selectedPriority = p
                    } label: {
                        if viewModel.selectedPriority == p {
                            Label(p.displayName, systemImage: "checkmark")
                        } else {
                            Text(p.displayName)
                        }
                    }
                }
            }
            Divider()
            Menu("Category") {
                Button {
                    viewModel.selectedCategory = nil
                } label: {
                    if viewModel.selectedCategory == nil {
                        Label("All", systemImage: "checkmark")
                    } else {
                        Text("All")
                    }
                }
                ForEach(categoryStore.categories, id: \.self) { cat in
                    Button {
                        viewModel.selectedCategory = cat
                    } label: {
                        if viewModel.selectedCategory == cat {
                            Label(cat, systemImage: "checkmark")
                        } else {
                            Text(cat)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease")
                if hasActiveFilters {
                    Circle()
                        .fill(.tint)
                        .frame(width: 6, height: 6)
                }
            }
        }
    }
    
    private var taskList: some View {
        List {
            ForEach(filteredTasks) { task in
                TaskRowView(task: task, onShare: {
                    taskToShare = task
                })
                    .contentShape(Rectangle())
                    .onTapGesture { taskToEdit = task }
                    .swipeActions(edge: .leading) {
                        Button {
                            withAnimation {
                                task.isCompleted.toggle()
                                task.completedAt = task.isCompleted ? Date() : nil
                                task.updatedAt = Date()
                                task.syncStatus = SyncStatus.pending.rawValue
                            }
                            _Concurrency.Task {
                                await syncEngine?.pushTask(task)
                            }
                        } label: {
                            Label(task.isCompleted ? "Undo" : "Complete",
                                  systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark")
                        }
                        .tint(task.isCompleted ? .orange : .green)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            // Capture data BEFORE deleting
                            let taskId = task.id
                            let taskSyncStatus = task.syncStatus
                            withAnimation {
                                modelContext.delete(task)
                            }
                            _Concurrency.Task {
                                await NotificationManager.shared.cancelNotification(taskId: taskId)
                                await syncEngine?.deleteRemoteTask(id: taskId, syncStatus: taskSyncStatus)
                            }
                        } label: { Label("Delete", systemImage: "trash") }
                    }
            }
            .onMove { indices, newOffset in
                var reordered = filteredTasks
                reordered.move(fromOffsets: indices, toOffset: newOffset)
                for (index, task) in reordered.enumerated() {
                    task.sortOrder = index
                    task.updatedAt = Date()
                    task.syncStatus = SyncStatus.pending.rawValue
                }
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, $editMode)
    }
    
    private func syncAll() async {
        guard let syncEngine = syncEngine else { return }
        await syncEngine.syncAll()
    }
}

#Preview {
    TaskListView()
        .modelContainer(for: Task.self, inMemory: true)
}
