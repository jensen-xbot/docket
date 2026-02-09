import SwiftUI

struct TaskConfirmationView: View {
    let tasks: [ParsedTask]
    let onConfirm: ([ParsedTask]) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(tasks) { task in
                    TaskPreviewRow(task: task)
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
                }
            }
        }
    }
}

struct TaskPreviewRow: View {
    let task: ParsedTask
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(task.title)
                .font(.headline)
            
            HStack(spacing: 12) {
                if let dueDate = task.dueDate {
                    Label(formatDate(dueDate), systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if let priority = Priority.fromString(task.priority) {
                    Label(priority.displayName, systemImage: priority.icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if let category = task.category {
                    Label(category, systemImage: "folder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if let notes = task.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            
            if let shareWith = task.shareWith {
                Label("Share with \(shareWith)", systemImage: "person.2")
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

#Preview {
    TaskConfirmationView(
        tasks: [
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
        ],
        onConfirm: { _ in },
        onCancel: { }
    )
}
