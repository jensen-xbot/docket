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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Title
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Title")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("What needs to be done?", text: $title, axis: .vertical)
                            .font(.title3)
                            .focused($titleFocused)
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
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("New Task")
            .toolbarTitleDisplayMode(.inline)
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
