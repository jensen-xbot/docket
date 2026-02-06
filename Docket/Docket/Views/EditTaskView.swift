import SwiftUI
import SwiftData

struct EditTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var task: Task
    
    @State private var title: String = ""
    @State private var priority: Priority = .medium
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    @State private var category: String = ""
    @State private var notes: String = ""
    
    @FocusState private var titleFocused: Bool
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    init(task: Task) {
        self.task = task
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Task title", text: $title, axis: .vertical)
                        .focused($titleFocused)
                }
                
                Section {
                    Toggle("Completed", isOn: $task.isCompleted)
                }
                
                Section("Details") {
                    Picker("Priority", selection: $priority) {
                        ForEach(Priority.allCases, id: \.self) { p in
                            Label(p.displayName, systemImage: p.icon).tag(p)
                        }
                    }
                    Toggle("Set due date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due date", selection: $dueDate, displayedComponents: [.date])
                    }
                }
                
                Section("Additional Info") {
                    TextField("Category (optional)", text: $category)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Button(role: .destructive) { deleteTask() } label: {
                        HStack { Spacer(); Text("Delete Task"); Spacer() }
                    }
                }
            }
            .navigationTitle("Edit Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { updateTask() }
                        .disabled(!isValid)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                title = task.title
                priority = task.priority
                hasDueDate = task.dueDate != nil
                if let due = task.dueDate { dueDate = due }
                category = task.category ?? ""
                notes = task.notes ?? ""
                titleFocused = true
            }
        }
    }
    
    private func updateTask() {
        task.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        task.priority = priority
        task.dueDate = hasDueDate ? dueDate : nil
        task.category = category.isEmpty ? nil : category
        task.notes = notes.isEmpty ? nil : notes
        dismiss()
    }
    
    private func deleteTask() {
        modelContext.delete(task)
        dismiss()
    }
}

#Preview {
    let task = Task(title: "Sample Task", priority: .high)
    return EditTaskView(task: task)
        .modelContainer(for: Task.self, inMemory: true)
}