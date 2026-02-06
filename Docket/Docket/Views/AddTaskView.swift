import SwiftUI
import SwiftData

struct AddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String = ""
    @State private var priority: Priority = .medium
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = .daysFromNow(1)
    @State private var category: String = ""
    @State private var notes: String = ""
    
    @FocusState private var titleFocused: Bool
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("What needs to be done?", text: $title, axis: .vertical)
                        .focused($titleFocused)
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
            }
            .navigationTitle("New Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveTask() }
                        .disabled(!isValid)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { titleFocused = true }
        }
    }
    
    private func saveTask() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let task = Task(
            title: trimmed,
            dueDate: hasDueDate ? dueDate : nil,
            priority: priority,
            category: category.isEmpty ? nil : category,
            notes: notes.isEmpty ? nil : notes
        )
        modelContext.insert(task)
        dismiss()
    }
}

#Preview {
    AddTaskView()
        .modelContainer(for: Task.self, inMemory: true)
}