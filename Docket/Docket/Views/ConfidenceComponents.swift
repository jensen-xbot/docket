import SwiftUI

// MARK: - Confidence Indicator

/// A visual indicator showing the AI's confidence in a parsed task
/// - High: Green checkmark + "Ready to add"
/// - Medium: Orange circle + "Tap to confirm"
/// - Low: Red bolt + "What do you mean?"
struct ConfidenceIndicator: View {
    let level: ConfidenceLevel
    
    private var icon: String {
        switch level {
        case .high:
            return "checkmark.circle.fill"
        case .medium:
            return "questionmark.circle.fill"
        case .low:
            return "bolt.trianglebadge.exclamationmark.fill"
        }
    }
    
    private var message: String {
        switch level {
        case .high:
            return "Ready to add"
        case .medium:
            return "Tap to confirm"
        case .low:
            return "What do you mean?"
        }
    }
    
    private var color: Color {
        switch level {
        case .high:
            return .green
        case .medium:
            return .orange
        case .low:
            return .red
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
            Text(message)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - Inline Confirmation Bar

/// An inline confirmation bar that appears below the command bar for medium confidence tasks
/// Shows task preview, due date chip, confidence indicator, and action buttons
struct InlineConfirmationBar: View {
    let task: ParsedTask
    let confidence: ConfidenceLevel
    var onConfirm: () -> Void
    var onEdit: () -> Void
    var onCancel: () -> Void
    
    @State private var isVisible = false
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                // Task title preview
                Text(task.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                HStack {
                    // Due date chip (if present)
                    if let dueDate = task.dueDate {
                        DueDateChip(date: dueDate, hasTime: task.hasTime)
                    }
                    
                    Spacer()
                    
                    // Confidence indicator
                    ConfidenceIndicator(level: confidence)
                }
                
                // Action buttons
                HStack(spacing: 12) {
                    Button(action: onCancel) {
                        Label("Cancel", systemImage: "xmark")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                    
                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    
                    Button(action: onConfirm) {
                        Label("Add", systemImage: "checkmark")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
        }
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.96)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isVisible)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85).delay(0.05)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Due Date Chip

/// A small chip showing the due date
struct DueDateChip: View {
    let date: Date
    let hasTime: Bool
    
    private var displayText: String {
        let formatter = DateFormatter()
        
        // Check if date is today
        if Calendar.current.isDateInToday(date) {
            if hasTime {
                formatter.dateFormat = "h:mm a"
                return "Today at \(formatter.string(from: date))"
            }
            return "Today"
        }
        
        // Check if date is tomorrow
        if Calendar.current.isDateInTomorrow(date) {
            if hasTime {
                formatter.dateFormat = "h:mm a"
                return "Tomorrow at \(formatter.string(from: date))"
            }
            return "Tomorrow"
        }
        
        // Check if date is within next 7 days
        let daysFromNow = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        if daysFromNow < 7 {
            if hasTime {
                formatter.dateFormat = "EEEE h:mm a"
                return formatter.string(from: date)
            }
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        }
        
        // Default format
        if hasTime {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
        }
        return formatter.string(from: date)
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.system(size: 12))
            Text(displayText)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemFill))
        .clipShape(Capsule())
    }
}

// MARK: - Quick Accept Toast

/// A toast notification that appears after auto-accepting a high-confidence task
/// Shows task title with undo option and auto-dismisses after 3 seconds
struct QuickAcceptToast: View {
    let taskTitle: String
    var onUndo: () -> Void
    
    @State private var isVisible = false
    @State private var progress: CGFloat = 1.0
    @Environment(\.dismiss) private var dismiss
    
    private let autoDismissDuration: TimeInterval = 3.0
    
    var body: some View {
        HStack(spacing: 12) {
            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.green)
            
            // Message
            VStack(alignment: .leading, spacing: 2) {
                Text("Added:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(taskTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Undo button
            Button(action: {
                withAnimation(.easeOut(duration: 0.2)) {
                    isVisible = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    onUndo()
                }
            }) {
                Text("Undo")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
        )
        .overlay(
            // Progress bar
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.green.opacity(0.3), lineWidth: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .trim(from: 0, to: progress)
                            .stroke(Color.green, lineWidth: 2)
                            .rotationEffect(.degrees(-90))
                    )
            }
        )
        .padding(.horizontal, 16)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.9)
        .offset(y: isVisible ? 0 : 20)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isVisible = true
            }
            startAutoDismiss()
        }
    }
    
    private func startAutoDismiss() {
        // Animate progress bar
        withAnimation(.linear(duration: autoDismissDuration)) {
            progress = 0
        }
        
        // Auto dismiss after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissDuration) {
            withAnimation(.easeOut(duration: 0.3)) {
                isVisible = false
            }
        }
    }
}

// MARK: - Preview Provider

#Preview("Confidence Components") {
    NavigationStack {
        List {
            Section("Confidence Indicators") {
                HStack {
                    ConfidenceIndicator(level: .high)
                    Spacer()
                }
                HStack {
                    ConfidenceIndicator(level: .medium)
                    Spacer()
                }
                HStack {
                    ConfidenceIndicator(level: .low)
                    Spacer()
                }
            }
            
            Section("Inline Confirmation Bar - High Confidence") {
                InlineConfirmationBar(
                    task: ParsedTask(
                        id: UUID(),
                        title: "Call Mom tomorrow at 3pm",
                        dueDate: Date().addingTimeInterval(86400),
                        hasTime: true,
                        priority: "medium",
                        category: "Family"
                    ),
                    confidence: .high,
                    onConfirm: {},
                    onEdit: {},
                    onCancel: {}
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            
            Section("Inline Confirmation Bar - Medium Confidence") {
                InlineConfirmationBar(
                    task: ParsedTask(
                        id: UUID(),
                        title: "Buy groceries",
                        dueDate: nil,
                        hasTime: false,
                        priority: "medium",
                        category: nil
                    ),
                    confidence: .medium,
                    onConfirm: {},
                    onEdit: {},
                    onCancel: {}
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            
            Section("Inline Confirmation Bar - Low Confidence") {
                InlineConfirmationBar(
                    task: ParsedTask(
                        id: UUID(),
                        title: "...",
                        dueDate: nil,
                        hasTime: false,
                        priority: "low",
                        category: nil
                    ),
                    confidence: .low,
                    onConfirm: {},
                    onEdit: {},
                    onCancel: {}
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Confidence UI")
    }
}

#Preview("Quick Accept Toast") {
    ZStack {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            QuickAcceptToast(
                taskTitle: "Call Mom tomorrow at 3pm",
                onUndo: {}
            )
            Spacer()
        }
    }
}

// MARK: - Convenience Extension

extension ParsedTask {
    /// Convenience initializer for previews and testing
    init(
        id: UUID = UUID(),
        title: String,
        dueDate: Date?,
        hasTime: Bool = false,
        priority: String = "medium",
        category: String? = nil,
        notes: String? = nil,
        shareWith: String? = nil,
        resolvedShareEmail: String? = nil,
        suggestion: String? = nil,
        checklistItems: [String]? = nil,
        useTemplate: String? = nil,
        recurrenceRule: String? = nil
    ) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.hasTime = hasTime
        self.priority = priority
        self.category = category
        self.notes = notes
        self.shareWith = shareWith
        self.resolvedShareEmail = resolvedShareEmail
        self.suggestion = suggestion
        self.checklistItems = checklistItems
        self.useTemplate = useTemplate
        self.recurrenceRule = recurrenceRule
    }
}