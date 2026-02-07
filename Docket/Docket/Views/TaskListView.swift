import SwiftUI
import SwiftData

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
        
        return result.sorted {
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
    
    @State private var viewModel = TaskListViewModel()
    @State private var showingAddTask = false
    @State private var taskToEdit: Task?
    
    private var filteredTasks: [Task] {
        viewModel.filteredTasks(from: allTasks)
    }

    private var hasActiveFilters: Bool {
        viewModel.selectedFilter != .all ||
        viewModel.selectedPriority != nil ||
        !viewModel.searchText.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if allTasks.isEmpty {
                    EmptyListView()
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
                    Button(action: { showingAddTask = true }) {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
            .fullScreenCover(isPresented: $showingAddTask) {
                AddTaskView()
            }
            .fullScreenCover(item: $taskToEdit) { task in
                EditTaskView(task: task)
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
                TaskRowView(task: task)
                    .contentShape(Rectangle())
                    .onTapGesture { taskToEdit = task }
                    .swipeActions(edge: .leading) {
                        Button {
                            withAnimation {
                                task.isCompleted.toggle()
                                task.completedAt = task.isCompleted ? Date() : nil
                            }
                        } label: {
                            Label(task.isCompleted ? "Undo" : "Complete",
                                  systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark")
                        }
                        .tint(task.isCompleted ? .orange : .green)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            withAnimation { modelContext.delete(task) }
                        } label: { Label("Delete", systemImage: "trash") }
                    }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    modelContext.delete(filteredTasks[index])
                }
            }
        }
        .listStyle(.plain)
    }
}

#Preview {
    TaskListView()
        .modelContainer(for: Task.self, inMemory: true)
}
