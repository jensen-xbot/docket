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
    
    // MARK: - Confidence Flow State
    @State private var showingQuickAcceptToast = false
    @State private var showingInlineConfirmation = false
    @State private var showingInlineEdit = false
    @State private var parsedTaskToEdit: ParsedTask?
    @State private var showingCommandBarExpanded = false
    @State private var lastParsedTasks: [ParsedTask] = []
    @State private var lastParseResponse: ParseResponse?
    @State private var parser = VoiceTaskParser()
    @State private var conversationMessages: [ConversationMessage] = []
    @State private var isProcessingConversation = false
    
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
            ZStack {
                mainContent
                
                // Quick Accept Toast (high confidence)
                if showingQuickAcceptToast, let task = lastParsedTasks.first {
                    VStack {
                        Spacer()
                        QuickAcceptToast(
                            taskTitle: task.title,
                            onUndo: {
                                showingQuickAcceptToast = false
                                // TODO: Implement undo logic
                            }
                        )
                        .padding(.bottom, 100)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Inline Confirmation Bar (medium confidence)
                if showingInlineConfirmation, let task = lastParsedTasks.first, let response = lastParseResponse {
                    VStack {
                        Spacer()
                        InlineConfirmationBar(
                            task: task,
                            confidence: response.effectiveConfidence,
                            onConfirm: {
                                saveParsedTasks(lastParsedTasks)
                                showingInlineConfirmation = false
                                viewModel.searchText = ""
                            },
                            onEdit: {
                                // Open inline edit mode
                                showingInlineConfirmation = false
                                parsedTaskToEdit = task
                                showingInlineEdit = true
                            },
                            onCancel: {
                                showingInlineConfirmation = false
                                lastParsedTasks = []
                            }
                        )
                        .padding(.bottom, 80)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Inline Edit Card (medium confidence → edit)
                if showingInlineEdit, var task = parsedTaskToEdit {
                    VStack {
                        Spacer()
                        InlineTaskEditView(
                            task: Binding(
                                get: { task },
                                set: { parsedTaskToEdit = $0 }
                            ),
                            onSave: {
                                if let finalTask = parsedTaskToEdit {
                                    saveParsedTasks([finalTask])
                                }
                                showingInlineEdit = false
                                parsedTaskToEdit = nil
                                viewModel.searchText = ""
                            },
                            onCancel: {
                                showingInlineEdit = false
                                parsedTaskToEdit = nil
                            }
                        )
                        .padding(.bottom, 80)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Expanded Command Bar (low confidence / conversation)
                if showingCommandBarExpanded {
                    CommandBarExpanded(
                        isExpanded: $showingCommandBarExpanded,
                        messages: $conversationMessages,
                        inputText: $viewModel.searchText,
                        onSend: { messageText in
                            handleConversationReply(messageText)
                        },
                        onVoiceTap: {
                            // Voice mode will be implemented in Module 4
                        },
                        onClose: {
                            showingCommandBarExpanded = false
                            conversationMessages = []
                        }
                    )
                }
            }
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
                            text: $viewModel.searchText,
                            onSubmit: { text, completion in
                                handleCommandSubmit(text, completion: completion)
                            },
                            onVoiceTap: {
                                showingVoiceRecording = true
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
            HStack(spacing: 12) {
                filterMenu
                SearchBar(text: $viewModel.searchText, placeholder: "Search")
            }
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
    
    private func handleCommandSubmit(_ text: String, completion: @escaping (ParseResponse) -> Void) {
        Task {
            // Initialize conversation with first message
            let messages = [ConversationMessage(role: "user", content: text)]
            
            do {
                let response = try await parser.send(messages: messages)
                await MainActor.run {
                    self.lastParseResponse = response
                    
                    switch response.effectiveConfidence {
                    case .high:
                        // Auto-accept with toast
                        if let tasks = response.tasks {
                            self.lastParsedTasks = tasks
                            self.showingQuickAcceptToast = true
                            // Auto-save after delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.saveParsedTasks(tasks)
                            }
                        }
                        
                    case .medium:
                        // Show inline confirmation
                        if let tasks = response.tasks {
                            self.lastParsedTasks = tasks
                            self.showingInlineConfirmation = true
                        }
                        
                    case .low:
                        // Expand for conversation
                        self.conversationMessages = [
                            ConversationMessage(role: "user", content: text)
                        ]
                        if let summary = response.summary {
                            self.conversationMessages.append(
                                ConversationMessage(role: "assistant", content: summary)
                            )
                        } else if let questionText = response.text {
                            self.conversationMessages.append(
                                ConversationMessage(role: "assistant", content: questionText)
                            )
                        }
                        self.showingCommandBarExpanded = true
                    }
                    
                    // Pass response to CommandBarView for UI handling
                    completion(response)
                }
            } catch {
                print("Parse error: \(error)")
                // Return a low-confidence response on error to trigger expanded mode
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
                    self.conversationMessages = [
                        ConversationMessage(role: "user", content: text),
                        ConversationMessage(role: "assistant", content: errorResponse.text ?? "I didn't understand that. Could you rephrase?")
                    ]
                    self.showingCommandBarExpanded = true
                    completion(errorResponse)
                }
            }
        }
    }
    
    private func handleConversationReply(_ text: String) {
        Task {
            // Add user message to conversation
            conversationMessages.append(ConversationMessage(role: "user", content: text))
            
            do {
                let response = try await parser.send(messages: conversationMessages)
                await MainActor.run {
                    self.lastParseResponse = response
                    
                    switch response.type {
                    case "complete":
                        if let tasks = response.tasks {
                            self.lastParsedTasks = tasks
                            
                            switch response.effectiveConfidence {
                            case .high:
                                // Auto-save and close
                                self.saveParsedTasks(tasks)
                                self.showingCommandBarExpanded = false
                                self.conversationMessages = []
                                self.showingQuickAcceptToast = true
                                
                            case .medium:
                                // Show inline confirmation (close expanded first)
                                self.showingCommandBarExpanded = false
                                self.showingInlineConfirmation = true
                                
                            case .low:
                                // Continue conversation
                                if let summary = response.summary {
                                    self.conversationMessages.append(
                                        ConversationMessage(role: "assistant", content: summary)
                                    )
                                }
                            }
                        }
                        
                    case "question":
                        // Continue conversation with question
                        if let questionText = response.text {
                            self.conversationMessages.append(
                                ConversationMessage(role: "assistant", content: questionText)
                            )
                        }
                        
                    default:
                        // Handle other response types
                        if let summary = response.summary {
                            self.conversationMessages.append(
                                ConversationMessage(role: "assistant", content: summary)
                            )
                        } else if let text = response.text {
                            self.conversationMessages.append(
                                ConversationMessage(role: "assistant", content: text)
                            )
                        }
                    }
                }
            } catch {
                print("Conversation parse error: \(error)")
                await MainActor.run {
                    self.conversationMessages.append(
                        ConversationMessage(role: "assistant", content: "Sorry, I had trouble processing that. Could you try again?")
                    )
                }
            }
        }
    }
    
    private func saveParsedTasks(_ tasks: [ParsedTask]) {
        Task {
            for parsedTask in tasks {
                let priority: Priority = {
                    switch parsedTask.priority.lowercased() {
                    case "low": return .low
                    case "high": return .high
                    default: return .medium
                    }
                }()
                
                let task = Task(
                    title: parsedTask.title,
                    dueDate: parsedTask.dueDate,
                    hasTime: parsedTask.hasTime,
                    priority: priority,
                    category: parsedTask.category,
                    notes: parsedTask.notes,
                    syncStatus: .pending
                )
                task.taskSource = "command_bar"
                task.voiceSnapshotData = try? JSONEncoder().encode(parsedTask.toVoiceSnapshot())
                
                // Handle checklist items / templates
                if let templateName = parsedTask.useTemplate {
                    // Load items from grocery store template
                    if let store = groceryStores.first(where: { $0.name.localizedCaseInsensitiveContains(templateName) }) {
                        let items = store.items.enumerated().map { index, name in
                            ChecklistItem(
                                id: UUID(),
                                name: name,
                                isChecked: false,
                                sortOrder: index,
                                quantity: 1,
                                isStarred: false
                            )
                        }
                        task.checklistItems = items
                    }
                } else if let itemNames = parsedTask.checklistItems, !itemNames.isEmpty {
                    // Create checklist items from AI-suggested names
                    let items = itemNames.enumerated().map { index, name in
                        let capitalizedName = name.split(separator: " ")
                            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
                            .joined(separator: " ")
                        return ChecklistItem(
                            id: UUID(),
                            name: capitalizedName,
                            isChecked: false,
                            sortOrder: index,
                            quantity: 1,
                            isStarred: false
                        )
                    }
                    task.checklistItems = items
                }
                
                // Handle sharing
                if let shareWith = parsedTask.shareWith, !shareWith.isEmpty {
                    task.shareWith = shareWith
                    // Share resolution happens in sync or background
                }
                
                modelContext.insert(task)
                
                // Schedule notification if due date exists
                if parsedTask.dueDate != nil {
                    await NotificationManager.shared.scheduleNotification(for: task)
                }
                
                // Push to sync engine
                await syncEngine.pushTask(task)
            }
            
            try? modelContext.save()
        }
    }
}

#Preview {
    TaskListView()
        .modelContainer(for: Task.self, inMemory: true)
}
