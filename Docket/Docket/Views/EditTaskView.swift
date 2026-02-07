import SwiftUI
import SwiftData
import _Concurrency

struct EditTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var task: Task
    
    @State private var title: String = ""
    @State private var priority: Priority = .medium
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    @State private var hasTime: Bool = false
    @State private var dueTime: Date = Date()
    @State private var category: String = ""
    @State private var notes: String = ""
    @State private var checklistItems: [ChecklistItem] = []
    @State private var showDeleteConfirm = false
    
    @FocusState private var titleFocused: Bool
    @FocusState private var notesFocused: Bool
    
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
                    // Category (chip picker)
                    CategoryPickerView(selectedCategory: $category)
                        .onChange(of: category) {
                            updateTitleForCategory()
                        }
                    
                    Divider()
                    
                    if isChecklistCategory || !checklistItems.isEmpty {
                        ChecklistEditorView(items: $checklistItems)
                        Divider()
                    }
                    
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
                    
                    // Priority (dismisses keyboard on tap)
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
                        .onChange(of: priority) {
                            titleFocused = false
                            notesFocused = false
                        }
                    }
                    
                    Divider()
                    
                    // Due Date
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $hasDueDate.animation(.easeInOut(duration: 0.2))) {
                            Label("Due Date", systemImage: "calendar")
                                .font(.subheadline)
                        }
                        .onChange(of: hasDueDate) {
                            if !hasDueDate {
                                hasTime = false
                            }
                        }
                        if hasDueDate {
                            DatePicker("", selection: $dueDate, displayedComponents: [.date])
                                .datePickerStyle(.graphical)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            
                            Toggle(isOn: $hasTime.animation(.easeInOut(duration: 0.2))) {
                                Label("Set Time", systemImage: "clock")
                                    .font(.subheadline)
                            }
                            
                            if hasTime {
                                DatePicker("", selection: $dueTime, displayedComponents: [.hourAndMinute])
                                    .datePickerStyle(.compact)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Notes
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("Add any extra details...", text: $notes, axis: .vertical)
                            .lineLimit(3...8)
                            .focused($notesFocused)
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
                .padding(.bottom, 200)
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
                hasTime = task.hasTime
                if let due = task.dueDate { dueTime = due }
                category = task.category ?? ""
                notes = task.notes ?? ""
                checklistItems = task.checklistItems ?? []
                titleFocused = true
                updateTitleForCategory()
            }
        }
    }
    
    private func updateTask() {
        task.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        task.priority = priority
        task.dueDate = hasDueDate ? (hasTime ? combineDateAndTime(date: dueDate, time: dueTime) : dueDate) : nil
        task.hasTime = hasTime
        task.category = category.isEmpty ? nil : category
        task.notes = notes.isEmpty ? nil : notes
        task.checklistItems = checklistItems.isEmpty ? nil : checklistItems
        task.completedAt = task.isCompleted ? (task.completedAt ?? Date()) : nil
        task.updatedAt = Date()
        task.syncStatus = SyncStatus.pending.rawValue
        _Concurrency.Task {
            await NotificationManager.shared.scheduleNotification(for: task)
        }
        dismiss()
    }
    
    private func deleteTask() {
        modelContext.delete(task)
        _Concurrency.Task {
            await NotificationManager.shared.cancelNotification(taskId: task.id)
        }
        dismiss()
    }
    
    private func updateTitleForCategory() {
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmedCategory.lowercased()
        let special = ["groceries", "shopping"]
        guard special.contains(lowercased) else { return }
        let currentTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if currentTitle.isEmpty || special.contains(currentTitle) {
            title = trimmedCategory.isEmpty ? "" : trimmedCategory.capitalized
        }
    }
    
    private var isChecklistCategory: Bool {
        let lowercased = category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lowercased == "groceries" || lowercased == "shopping"
    }
    
    private func combineDateAndTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        return calendar.date(from: dateComponents) ?? date
    }
}

#Preview {
    let task = Task(title: "Sample Task", priority: .high)
    return EditTaskView(task: task)
        .modelContainer(for: Task.self, inMemory: true)
}
