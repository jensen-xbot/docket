import SwiftUI
import SwiftData
import _Concurrency
import Combine

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
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(SyncEngine.self) private var syncEngine
    @Query(sort: \Task.createdAt, order: .reverse) private var allTasks: [Task]
    
    var authManager: AuthManager?
    
    @State private var viewModel = TaskListViewModel()
    @State private var showingAddTask = false
    @State private var showingVoiceRecording = false
    @State private var taskToEdit: Task?
    @State private var taskToShare: Task?
    @State private var currentUserProfile: UserProfile?
    @State private var pendingTaskId: UUID?
    
    private var filteredTasks: [Task] {
        viewModel.filteredTasks(from: allTasks)
    }

    private var categoryStore: CategoryStore { CategoryStore.shared }
    
    private var hasActiveFilters: Bool {
        viewModel.selectedFilter != .all ||
        viewModel.selectedPriority != nil ||
        viewModel.selectedCategory != nil ||
        !viewModel.searchText.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("Docket")
                .toolbar { toolbarContent }
                .refreshable { await syncAll() }
                .onAppear(perform: onViewAppear)
                .onChange(of: pendingTaskId) { _, taskId in
                    handlePendingTaskNavigation(taskId)
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PendingTaskNavigation"))) { notification in
                    if let taskId = notification.object as? UUID {
                        pendingTaskId = taskId
                    }
                }
                .fullScreenCover(isPresented: $showingAddTask) { AddTaskView() }
                .fullScreenCover(isPresented: $showingVoiceRecording) { VoiceRecordingView() }
                .fullScreenCover(item: $taskToEdit) { task in EditTaskView(task: task) }
                .sheet(item: $taskToShare) { task in ShareTaskView(task: task) }
                .safeAreaInset(edge: .bottom) {
                    if !networkMonitor.isConnected || pendingCount > 0 {
                        offlinePendingBanner
                    }
                }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search tasks")
    }
    
    private var pendingCount: Int {
        let syncedValue = SyncStatus.synced.rawValue
        return allTasks.filter { $0.syncStatus != syncedValue }.count
    }
    
    @ViewBuilder
    private var offlinePendingBanner: some View {
        VStack(spacing: 0) {
            if !networkMonitor.isConnected {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .font(.caption)
                    Text("Offline")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red)
                .cornerRadius(8)
            }
            
            if pendingCount > 0 && networkMonitor.isConnected {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                    Text("\(pendingCount) change\(pendingCount == 1 ? "" : "s") pending")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange)
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    @ViewBuilder
    private var mainContent: some View {
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
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            filterMenu
        }
        ToolbarItem(placement: .topBarTrailing) {
            trailingToolbar
        }
    }
    
    private var trailingToolbar: some View {
        HStack(spacing: 12) {
            if syncEngine.isSyncing {
                ProgressView()
                    .scaleEffect(0.8)
            }
            
            if let authManager = authManager {
                NavigationLink {
                    ProfileView(authManager: authManager)
                } label: {
                    Image(systemName: "person.circle")
                }
            }
            
            Button(action: { showingVoiceRecording = true }) {
                Image(systemName: "mic.fill")
                    .fontWeight(.semibold)
            }
            
            if !allTasks.isEmpty {
                Button(action: { showingAddTask = true }) {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func onViewAppear() {
        _Concurrency.Task {
            await syncAll()
            await loadCurrentUserProfile()
        }
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
                ForEach(categoryStore.categories) { categoryItem in
                    Button {
                        viewModel.selectedCategory = categoryItem.name
                    } label: {
                        if viewModel.selectedCategory == categoryItem.name {
                            Label(categoryItem.name, systemImage: "checkmark")
                        } else {
                            Text(categoryItem.name)
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
                taskRow(for: task)
            }
            .onMove(perform: handleReorder)
        }
        .listStyle(.plain)
    }
    
    private func taskRow(for task: Task) -> some View {
        let profile: UserProfile? = task.isShared ? syncEngine.sharerProfiles[task.userId ?? ""] : nil
        return TaskRowView(
            task: task,
            syncEngine: syncEngine,
            onShare: { taskToShare = task },
            currentUserProfile: currentUserProfile,
            sharerProfile: profile
        )
        .contentShape(Rectangle())
        .onTapGesture { taskToEdit = task }
        .swipeActions(edge: .leading) {
            completeSwipeButton(for: task)
        }
        .swipeActions(edge: .trailing) {
            deleteSwipeButton(for: task)
        }
    }
    
    private func completeSwipeButton(for task: Task) -> some View {
        Button {
            withAnimation {
                task.isCompleted.toggle()
                task.completedAt = task.isCompleted ? Date() : nil
                task.updatedAt = Date()
                task.syncStatus = SyncStatus.pending.rawValue
            }
            _Concurrency.Task {
                await syncEngine.pushTask(task)
            }
        } label: {
            Label(task.isCompleted ? "Undo" : "Complete",
                  systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark")
        }
        .tint(task.isCompleted ? .orange : .green)
    }
    
    private func deleteSwipeButton(for task: Task) -> some View {
        Button(role: .destructive) {
            let taskId = task.id
            let taskSyncStatus = task.syncStatus
            withAnimation {
                modelContext.delete(task)
            }
            _Concurrency.Task {
                await NotificationManager.shared.cancelNotification(taskId: taskId)
                await syncEngine.deleteRemoteTask(id: taskId, syncStatus: taskSyncStatus)
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    
    private func handleReorder(indices: IndexSet, newOffset: Int) {
        var reordered = filteredTasks
        reordered.move(fromOffsets: indices, toOffset: newOffset)
        for (index, task) in reordered.enumerated() {
            task.sortOrder = index
            task.updatedAt = Date()
            task.syncStatus = SyncStatus.pending.rawValue
        }
        let tasksToSync = reordered
        _Concurrency.Task {
            for task in tasksToSync {
                await syncEngine.pushTask(task)
            }
        }
    }
    
    private func syncAll() async {
        await syncEngine.syncAll()
    }
    
    private func loadCurrentUserProfile() async {
        do {
            let session = try await SupabaseConfig.client.auth.session
            let userId = session.user.id.uuidString
            
            let profiles: [UserProfile] = try await SupabaseConfig.client
                .from("user_profiles")
                .select()
                .eq("id", value: userId)
                .execute()
                .value
            
            currentUserProfile = profiles.first
        } catch {
            print("Error loading current user profile: \(error)")
        }
    }
    
    private func handlePendingTaskNavigation(_ taskId: UUID?) {
        guard let taskId = taskId else { return }
        
        // Sync first to ensure the shared task is pulled
        _Concurrency.Task {
            await syncAll()
            
            // Find the task in local SwiftData
            let descriptor = FetchDescriptor<Task>(
                predicate: #Predicate<Task> { $0.id == taskId }
            )
            
            if let task = try? modelContext.fetch(descriptor).first {
                // Open the task
                taskToEdit = task
            }
            
            // Clear the pending navigation
            PushNotificationManager.shared.pendingTaskNavigation = nil
            pendingTaskId = nil
        }
    }
}

#Preview {
    TaskListView()
        .modelContainer(for: Task.self, inMemory: true)
}
