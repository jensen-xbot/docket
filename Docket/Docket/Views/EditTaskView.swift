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
    @State private var showDeleteConfirm = false
    
    @FocusState private var titleFocused: Bool
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    init(task: Task) {
        self.task = task
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Title
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Title")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("Task title", text: $title, axis: .vertical)
                            .font(.title3)
                            .focused($titleFocused)
                    }
                    
                    Divider()
                    
                    // Completed toggle
                    Toggle(isOn: $task.isCompleted) {
                        Label("Completed", systemImage: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    }
                    
                    Divider()
                    
                    // Priority
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Priority")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Picker("Priority", selection: $priority) {
                            ForEach(Priority.allCases, id: \.self) { p in
                                Text(p.displayName).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Divider()
                    
                    // Due Date
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $hasDueDate.animation(.easeInOut(duration: 0.2))) {
                            Label("Due Date", systemImage: "calendar")
                                .font(.subheadline)
                        }
                        if hasDueDate {
                            DatePicker("", selection: $dueDate, displayedComponents: [.date])
                                .datePickerStyle(.graphical)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    
                    Divider()
                    
                    // Category
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Category")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("e.g. Work, Personal, Family", text: $category)
                    }
                    
                    Divider()
                    
                    // Notes
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("Add any extra details...", text: $notes, axis: .vertical)
                            .lineLimit(3...8)
                    }
                    
                    Divider()
                    
                    // Delete
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Task")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit Task")
            .toolbarTitleDisplayMode(.inline)
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
            .confirmationDialog("Delete this task?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { deleteTask() }
                Button("Cancel", role: .cancel) { }
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
        task.completedAt = task.isCompleted ? (task.completedAt ?? Date()) : nil
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
