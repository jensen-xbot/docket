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
    @AppStorage("openVoiceRecordingFromShortcut") private var openVoiceRecordingFromShortcut = false
    @State private var taskToEdit: Task?
    @State private var taskToShare: Task?
    @State private var currentUserProfile: UserProfile?
    @State private var pendingTaskId: UUID?
    @State private var showContactsForInvite = false
    @State private var unreadNotificationCount = 0
    @State private var activeProgressTaskId: UUID?
    @State private var isSearchPresented = false
    @FocusState private var isSearchFocused: Bool
    
    @State private var parser = VoiceTaskParser()
    
    // MARK: - Grocery Stores (for templates)
    @Query(sort: \GroceryStore.name) private var groceryStores: [GroceryStore]
    
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
            VStack(spacing: 0) {
                // Inline search bar at the top of the content area
                if isSearchPresented {
                    inlineSearchBar
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                mainContent
            }
            .animation(.easeInOut(duration: 0.25), value: isSearchPresented)
            .navigationTitle("Docket")
                .toolbar { toolbarContent }
                .refreshable {
                    await syncAll()
                    await loadUnreadNotificationCount()
                }
                .onAppear(perform: onViewAppear)
                .onChange(of: openVoiceRecordingFromShortcut) { _, shouldOpen in
                    if shouldOpen {
                        showingVoiceRecording = true
                        openVoiceRecordingFromShortcut = false
                    }
                }
                .onChange(of: taskToShare) { _, newValue in
                    if newValue == nil {
                        _Concurrency.Task { await syncAll() }
                    }
                }
                .onChange(of: pendingTaskId) { _, taskId in
                    handlePendingTaskNavigation(taskId)
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PendingTaskNavigation"))) { notification in
                    if let taskId = notification.object as? UUID {
                        pendingTaskId = taskId
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PendingInviteView"))) { _ in
                    showContactsForInvite = true
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NotificationsViewDismissed"))) { _ in
                    _Concurrency.Task { await loadUnreadNotificationCount() }
                }
                .fullScreenCover(isPresented: $showingAddTask) { AddTaskView() }
                .sheet(isPresented: $showingVoiceRecording) { VoiceRecordingView() }
                .fullScreenCover(item: $taskToEdit) { task in EditTaskView(task: task) }
                .sheet(item: $taskToShare) { task in ShareTaskView(task: task) }
                .fullScreenCover(isPresented: $showContactsForInvite) {
                    NavigationStack {
                        ContactsListView()
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Done") {
                                        showContactsForInvite = false
                                        PushNotificationManager.shared.pendingInviteView = false
                                    }
                                }
                            }
                    }
                    .environment(syncEngine)
                    .environment(networkMonitor)
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 0) {
                        if !networkMonitor.isConnected {
                            offlinePendingBanner
                        }
                        
                        CommandBarView(
                            onSubmit: { messages, completion in
                                handleCommandSubmit(messages: messages, completion: completion)
                            },
                            onVoiceTap: {
                                showingVoiceRecording = true
                            },
                            onAddTask: {
                                showingAddTask = true
                            }
                        )
                    }
                }
        }
    }
    
    private var pendingCount: Int {
        let syncedValue = SyncStatus.synced.rawValue
        return allTasks.filter { $0.syncStatus != syncedValue }.count
    }
    
    @ViewBuilder
    private var offlinePendingBanner: some View {
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
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
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
        ToolbarItem(placement: .topBarLeading) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isSearchPresented = true
                    isSearchFocused = true
                }
            } label: {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.blue)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            trailingToolbar
        }
    }
    
    private var inlineSearchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                TextField("Search tasks", text: $viewModel.searchText)
                    .focused($isSearchFocused)
                    .font(.body)
                    .submitLabel(.search)
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            Button("Cancel") {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.searchText = ""
                    isSearchPresented = false
                    isSearchFocused = false
                }
            }
            .font(.body)
        }
    }
    
    private var trailingToolbar: some View {
        HStack(spacing: 12) {
            if syncEngine.isSyncing {
                ProgressView()
                    .scaleEffect(0.8)
            }
            
            NavigationLink {
                NotificationsListView()
                    .environment(syncEngine)
                    .environment(networkMonitor)
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                    if unreadNotificationCount > 0 {
                        Text("\(min(unreadNotificationCount, 99))")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 8, y: -8)
                    }
                }
            }
            
            if let authManager = authManager {
                NavigationLink {
                    ProfileView(authManager: authManager)
                } label: {
                    Image(systemName: "person.circle")
                }
            }
        }
    }
    
    private func onViewAppear() {
        if openVoiceRecordingFromShortcut {
            showingVoiceRecording = true
            openVoiceRecordingFromShortcut = false
        }
        _Concurrency.Task {
            await syncAll()
            await loadCurrentUserProfile()
            await loadUnreadNotificationCount()
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
        .scrollDismissesKeyboard(.interactively)
    }
    
    private func taskRow(for task: Task) -> some View {
        let sharerKey = (task.userId ?? "").uppercased()
        let profile: UserProfile? = task.isShared ? syncEngine.sharerProfiles[sharerKey] : nil
        let sharedWith: [UserProfile] = task.isShared ? [] : (syncEngine.sharedWithProfiles[task.id] ?? [])
        return TaskRowView(
            task: task,
            syncEngine: syncEngine,
            onShare: { taskToShare = task },
            currentUserProfile: currentUserProfile,
            sharerProfile: profile,
            sharedWithProfiles: sharedWith,
            activeProgressTaskId: $activeProgressTaskId
        )
        .contentShape(Rectangle())
        .onTapGesture {
            // Dismiss any open slider when tapping a row to edit
            activeProgressTaskId = nil
            taskToEdit = task
        }
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
    
    private func loadUnreadNotificationCount() async {
        do {
            let session = try await SupabaseConfig.client.auth.session
            let userId = session.user.id.uuidString
            
            struct NotifRow: Codable {
                let id: UUID
                let readAt: Date?
                enum CodingKeys: String, CodingKey { case id; case readAt = "read_at" }
            }
            let rows: [NotifRow] = try await SupabaseConfig.client
                .from("notifications")
                .select("id, read_at")
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value
            
            unreadNotificationCount = rows.filter { $0.readAt == nil }.count
        } catch {
            unreadNotificationCount = 0
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
    
    private func buildTaskContext(userText: String = "") -> [TaskContext] {
        let active = Array(allTasks.filter { !$0.isCompleted }.prefix(50))
        let recentCompleted = Array(allTasks.filter { $0.isCompleted }.prefix(20))
        
        let keywords = userText.lowercased()
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count >= 2 && !["the", "and", "for", "with", "tomorrow", "today", "next", "this", "that", "add", "create", "make", "schedule", "remind", "me", "my", "to", "a", "an", "on", "at", "by", "is", "it"].contains($0) }
        
        let tasksToSend: [Task]
        if !keywords.isEmpty {
            let matched = (active + recentCompleted)
                .filter { task in
                    let titleLower = task.title.lowercased()
                    return keywords.contains { titleLower.contains($0) }
                }
                .prefix(10)
            let matchedIds = Set(matched.map { $0.id.uuidString })
            let recent = active.filter { !matchedIds.contains($0.id.uuidString) }.prefix(15)
            tasksToSend = Array(matched + recent)
        } else {
            tasksToSend = Array(active.prefix(20) + recentCompleted.prefix(5))
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        let dateTimeFormatter = DateFormatter()
        dateTimeFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        dateTimeFormatter.timeZone = TimeZone.current
        
        return tasksToSend.map { task in
            let dueDateString: String?
            if let dueDate = task.dueDate {
                if task.hasTime {
                    dueDateString = dateTimeFormatter.string(from: dueDate)
                } else {
                    dueDateString = dateFormatter.string(from: dueDate)
                }
            } else {
                dueDateString = nil
            }
            
            let priorityString: String = {
                switch task.priority {
                case .low: return "low"
                case .high: return "high"
                default: return "medium"
                }
            }()
            
            return TaskContext(
                id: task.id.uuidString,
                title: task.title,
                dueDate: dueDateString,
                priority: priorityString,
                category: task.category,
                isCompleted: task.isCompleted,
                progressPercentage: task.progressPercentage,
                isProgressEnabled: task.isProgressEnabled,
                recurrenceRule: task.recurrenceRule
            )
        }
    }
    
    private func buildGroceryStoreContext() -> [GroceryStoreContext] {
        groceryStores.map { store in
            GroceryStoreContext(
                name: store.name,
                itemCount: store.items.count
            )
        }
    }
    
    private func handleCommandSubmit(messages: [ConversationMessage], completion: @escaping (ParseResponse) -> Void) {
        let userText = messages.last?.content ?? ""
        let existingTasks = buildTaskContext(userText: userText)
        let groceryStoresContext = buildGroceryStoreContext()
        _Concurrency.Task {
            do {
                _ = try await parser.sendStreaming(messages: messages, existingTasks: existingTasks, groceryStores: groceryStoresContext) { response in
                    _Concurrency.Task { @MainActor in completion(response) }
                }
            } catch {
                print("Parse error: \(error)")
                let errorResponse = ParseResponse(
                    type: "question",
                    text: "I didn't understand that. Could you rephrase?",
                    tasks: nil,
                    taskId: nil,
                    changes: nil,
                    summary: nil,
                    confidence: .low
                )
                await MainActor.run {
                    completion(errorResponse)
                }
            }
        }
    }
    
}

#Preview {
    TaskListView()
        .modelContainer(for: Task.self, inMemory: true)
}
