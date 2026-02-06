import Foundation
import SwiftData

@Model
class Task {
    @Attribute(.unique) var id: UUID
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    var dueDate: Date?
    var priority: Priority
    var category: String?
    var notes: String?
    var completedAt: Date?
    
    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        dueDate: Date? = nil,
        priority: Priority = .medium,
        category: String? = nil,
        notes: String? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.priority = priority
        self.category = category
        self.notes = notes
        self.completedAt = completedAt
    }
    
    var isOverdue: Bool {
        guard let dueDate = dueDate, !isCompleted else { return false }
        return dueDate < Date()
    }
    
    var isDueSoon: Bool {
        guard let dueDate = dueDate, !isCompleted else { return false }
        let calendar = Calendar.current
        let daysUntilDue = calendar.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
        return daysUntilDue >= 0 && daysUntilDue <= 3
    }
}

enum Priority: Int, CaseIterable, Codable {
    case low = 0
    case medium = 1
    case high = 2
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "arrow.down"
        case .medium: return "arrow.right"
        case .high: return "arrow.up"
        }
    }
}