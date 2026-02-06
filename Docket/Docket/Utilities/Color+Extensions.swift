import SwiftUI

extension Color {
    // MARK: - Priority Colors
    
    static var priorityLow: Color {
        Color.gray
    }
    
    static var priorityMedium: Color {
        Color.orange
    }
    
    static var priorityHigh: Color {
        Color.red
    }
    
    static func priorityColor(_ priority: Priority) -> Color {
        switch priority {
        case .low:
            return .priorityLow
        case .medium:
            return .priorityMedium
        case .high:
            return .priorityHigh
        }
    }
    
    // MARK: - Due Date Colors
    
    static var dueDateFar: Color {
        Color.green
    }
    
    static var dueDateSoon: Color {
        Color.yellow
    }
    
    static var dueDateOverdue: Color {
        Color.red
    }
    
    static func dueDateColor(for task: Task) -> Color {
        guard !task.isCompleted else { return .secondary }
        
        if task.isOverdue {
            return .dueDateOverdue
        } else if task.isDueSoon {
            return .dueDateSoon
        } else {
            return .dueDateFar
        }
    }
    
    // MARK: - Semantic Colors for Dark/Light Mode
    
    static var taskBackground: Color {
        Color(.systemBackground)
    }
    
    static var taskSecondaryBackground: Color {
        Color(.secondarySystemBackground)
    }
    
    static var taskGroupedBackground: Color {
        Color(.systemGroupedBackground)
    }
    
    static var taskSeparator: Color {
        Color(.separator)
    }
    
    static var taskFill: Color {
        Color(.systemFill)
    }
    
    static var taskSecondaryFill: Color {
        Color(.secondarySystemFill)
    }
}