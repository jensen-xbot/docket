import Foundation
import SwiftData

enum SyncStatus: Int, Codable {
    case synced = 0
    case pending = 1
    case failed = 2
}

@Model
class Task {
    @Attribute(.unique) var id: UUID
    var userId: String?
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    var dueDate: Date?
    var hasTime: Bool
    var priority: Priority
    var category: String?
    var notes: String?
    var completedAt: Date?
    var isPinned: Bool
    var sortOrder: Int
    var checklistItemsData: Data?
    var isShared: Bool
    var syncStatus: Int // SyncStatus rawValue
    var updatedAt: Date
    
    var checklistItems: [ChecklistItem]? {
        get {
            guard let data = checklistItemsData else { return nil }
            return try? JSONDecoder().decode([ChecklistItem].self, from: data)
        }
        set {
            if let items = newValue, !items.isEmpty {
                checklistItemsData = try? JSONEncoder().encode(items)
            } else {
                checklistItemsData = nil
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        userId: String? = nil,
        title: String,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        dueDate: Date? = nil,
        hasTime: Bool = false,
        priority: Priority = .medium,
        category: String? = nil,
        notes: String? = nil,
        completedAt: Date? = nil,
        isPinned: Bool = false,
        sortOrder: Int = 0,
        checklistItems: [ChecklistItem]? = nil,
        isShared: Bool = false,
        syncStatus: SyncStatus = .pending,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.hasTime = hasTime
        self.priority = priority
        self.category = category
        self.notes = notes
        self.completedAt = completedAt
        self.isPinned = isPinned
        self.sortOrder = sortOrder
        if let items = checklistItems, !items.isEmpty {
            self.checklistItemsData = try? JSONEncoder().encode(items)
        } else {
            self.checklistItemsData = nil
        }
        self.isShared = isShared
        self.syncStatus = syncStatus.rawValue
        self.updatedAt = updatedAt
    }
    
    var syncStatusEnum: SyncStatus {
        get { SyncStatus(rawValue: syncStatus) ?? .pending }
        set { syncStatus = newValue.rawValue }
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

// Codable representation for Supabase sync
struct TaskDTO: Codable {
    let id: UUID
    let userId: String
    let title: String
    let isCompleted: Bool
    let createdAt: Date
    let dueDate: Date?
    let hasTime: Bool
    let priority: String // "low", "medium", "high"
    let category: String?
    let notes: String?
    let completedAt: Date?
    let isPinned: Bool
    let sortOrder: Int
    let checklistItems: [ChecklistItem]?
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case isCompleted = "is_completed"
        case createdAt = "created_at"
        case dueDate = "due_date"
        case hasTime = "has_time"
        case priority
        case category
        case notes
        case completedAt = "completed_at"
        case isPinned = "is_pinned"
        case sortOrder = "sort_order"
        case checklistItems = "checklist_items"
        case updatedAt = "updated_at"
    }
    
    init(from task: Task, userId: String) {
        self.id = task.id
        self.userId = userId
        self.title = task.title
        self.isCompleted = task.isCompleted
        self.createdAt = task.createdAt
        self.dueDate = task.dueDate
        self.hasTime = task.hasTime
        self.priority = task.priority.displayName.lowercased()
        self.category = task.category
        self.notes = task.notes
        self.completedAt = task.completedAt
        self.isPinned = task.isPinned
        self.sortOrder = task.sortOrder
        self.checklistItems = task.checklistItems
        self.updatedAt = task.updatedAt
    }
    
    func toTask() -> Task {
        let priorityEnum: Priority = {
            switch priority.lowercased() {
            case "low": return .low
            case "high": return .high
            default: return .medium
            }
        }()
        
        return Task(
            id: id,
            userId: userId,
            title: title,
            isCompleted: isCompleted,
            createdAt: createdAt,
            dueDate: dueDate,
            hasTime: hasTime,
            priority: priorityEnum,
            category: category,
            notes: notes,
            completedAt: completedAt,
            isPinned: isPinned,
            sortOrder: sortOrder,
            checklistItems: checklistItems,
            syncStatus: .synced,
            updatedAt: updatedAt
        )
    }
}

struct ChecklistItem: Codable, Identifiable {
    var id: UUID
    var name: String
    var isChecked: Bool
    var sortOrder: Int
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
