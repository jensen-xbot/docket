import SwiftUI

struct TaskConfirmationView: View {
    @Binding var tasks: [ParsedTask]
    let onConfirm: ([ParsedTask]) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, _ in
                    TaskPreviewRow(task: Binding(
                        get: { tasks[index] },
                        set: { tasks[index] = $0 }
                    ))
                }
                .onDelete { indexSet in
                    tasks.remove(atOffsets: indexSet)
                }
            }
            .navigationTitle("Confirm Tasks")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add All (\(tasks.count))") {
                        onConfirm(tasks)
                    }
                    .fontWeight(.semibold)
                    .disabled(tasks.isEmpty)
                }
            }
        }
    }
}

struct TaskPreviewRow: View {
    @Binding var task: ParsedTask
    @State private var isEditingTitle = false
    @State private var isEditingCategory = false
    @FocusState private var titleFocused: Bool
    @FocusState private var categoryFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title — tap to edit
            if isEditingTitle {
                TextField("Title", text: $task.title)
                    .font(.headline)
                    .focused($titleFocused)
                    .onSubmit {
                        isEditingTitle = false
                        titleFocused = false
                    }
            } else {
                Button {
                    isEditingTitle = true
                    titleFocused = true
                } label: {
                    Text(task.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            
            HStack(spacing: 12) {
                if let dueDate = task.dueDate {
                    Label(formatDate(dueDate), systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Priority — tap to cycle low → medium → high → low
                Button {
                    task.priority = nextPriority(after: task.priority)
                } label: {
                    if let priority = Priority.fromString(task.priority) {
                        Label(priority.displayName, systemImage: priority.icon)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                // Category — tap to edit
                if isEditingCategory {
                    TextField("Category", text: Binding(
                        get: { task.category ?? "" },
                        set: { task.category = $0.isEmpty ? nil : $0 }
                    ))
                    .font(.caption)
                    .focused($categoryFocused)
                    .onSubmit {
                        isEditingCategory = false
                        categoryFocused = false
                    }
                } else {
                    Button {
                        isEditingCategory = true
                        categoryFocused = true
                    } label: {
                        if let category = task.category {
                            Label(category, systemImage: "folder")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Label("Add category", systemImage: "folder.badge.plus")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if let notes = task.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            
            if let shareWith = task.shareWith {
                let shareLabel: String = {
                    if let email = task.resolvedShareEmail, email != shareWith {
                        return "Share with \(shareWith) (\(email))"
                    }
                    return "Share with \(shareWith)"
                }()
                Label(shareLabel, systemImage: "person.2")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .padding(.top, 4)
            }
            
            if let suggestion = task.suggestion {
                Text(suggestion)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .italic()
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func nextPriority(after priority: String) -> String {
        switch priority.lowercased() {
        case "low": return "medium"
        case "high": return "low"
        default: return "high"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

extension Priority {
    static func fromString(_ string: String) -> Priority? {
        switch string.lowercased() {
        case "low": return .low
        case "medium": return .medium
        case "high": return .high
        default: return nil
        }
    }
}

struct TaskConfirmationView_Previews: PreviewProvider {
    static var previews: some View {
        TaskConfirmationView(
            tasks: .constant([
                ParsedTask(
                    id: UUID(),
                    title: "Call Mom",
                    dueDate: Date().addingTimeInterval(86400),
                    hasTime: false,
                    priority: "high",
                    category: "Family",
                    notes: "She wants to talk about the weekend trip",
                    shareWith: nil,
                    suggestion: nil
                )
            ]),
            onConfirm: { _ in },
            onCancel: { }
        )
    }
}
