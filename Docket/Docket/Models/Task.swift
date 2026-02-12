import Foundation
import SwiftData

/// Snapshot of AI output at voice task creation time (for correction tracking)
struct VoiceSnapshot: Codable {
    let title: String
    let dueDate: String? // ISO 8601
    let hasTime: Bool
    let priority: String
    let category: String?
    let notes: String?
}

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
    
    // Progress tracking (v1.3)
    var progressPercentage: Double = 0.0 // 0.0 - 100.0
    var isProgressEnabled: Bool = false // per-task toggle
    var lastProgressUpdate: Date?
    
    // Recurring (nil = not recurring, "daily"|"weekly"|"monthly")
    var recurrenceRule: String?
    
    // Voice personalization (Phase 10)
    var taskSource: String? // "voice" or nil (manual/legacy)
    var voiceSnapshotData: Data? // encoded VoiceSnapshot at creation time
    
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
        updatedAt: Date = Date(),
        progressPercentage: Double = 0.0,
        isProgressEnabled: Bool = false,
        lastProgressUpdate: Date? = nil,
        recurrenceRule: String? = nil,
        taskSource: String? = nil,
        voiceSnapshotData: Data? = nil
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
        self.progressPercentage = progressPercentage
        self.isProgressEnabled = isProgressEnabled
        self.lastProgressUpdate = lastProgressUpdate
        self.recurrenceRule = recurrenceRule
        self.taskSource = taskSource
        self.voiceSnapshotData = voiceSnapshotData
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
    var progressPercentage: Double
    var isProgressEnabled: Bool
    var lastProgressUpdate: Date?
    var recurrenceRule: String?
    var taskSource: String?
    var voiceSnapshot: VoiceSnapshot?
    
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
        case progressPercentage = "progress_percentage"
        case isProgressEnabled = "is_progress_enabled"
        case lastProgressUpdate = "last_progress_update"
        case recurrenceRule = "recurrence_rule"
        case taskSource = "task_source"
        case voiceSnapshot = "voice_snapshot"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        title = try container.decode(String.self, forKey: .title)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        hasTime = try container.decodeIfPresent(Bool.self, forKey: .hasTime) ?? false
        priority = try container.decode(String.self, forKey: .priority)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        checklistItems = try container.decodeIfPresent([ChecklistItem].self, forKey: .checklistItems)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        progressPercentage = try container.decodeIfPresent(Double.self, forKey: .progressPercentage) ?? 0.0
        isProgressEnabled = try container.decodeIfPresent(Bool.self, forKey: .isProgressEnabled) ?? false
        lastProgressUpdate = try container.decodeIfPresent(Date.self, forKey: .lastProgressUpdate)
        recurrenceRule = try container.decodeIfPresent(String.self, forKey: .recurrenceRule)
        taskSource = try container.decodeIfPresent(String.self, forKey: .taskSource)
        voiceSnapshot = try container.decodeIfPresent(VoiceSnapshot.self, forKey: .voiceSnapshot)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(title, forKey: .title)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(dueDate, forKey: .dueDate)
        try container.encode(hasTime, forKey: .hasTime)
        try container.encode(priority, forKey: .priority)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encodeIfPresent(checklistItems, forKey: .checklistItems)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(progressPercentage, forKey: .progressPercentage)
        try container.encode(isProgressEnabled, forKey: .isProgressEnabled)
        try container.encodeIfPresent(lastProgressUpdate, forKey: .lastProgressUpdate)
        try container.encodeIfPresent(recurrenceRule, forKey: .recurrenceRule)
        try container.encodeIfPresent(taskSource, forKey: .taskSource)
        try container.encodeIfPresent(voiceSnapshot, forKey: .voiceSnapshot)
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
        self.progressPercentage = task.progressPercentage
        self.isProgressEnabled = task.isProgressEnabled
        self.lastProgressUpdate = task.lastProgressUpdate
        self.recurrenceRule = task.recurrenceRule
        self.taskSource = task.taskSource
        self.voiceSnapshot = task.voiceSnapshotData.flatMap { try? JSONDecoder().decode(VoiceSnapshot.self, from: $0) }
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
            updatedAt: updatedAt,
            progressPercentage: progressPercentage,
            isProgressEnabled: isProgressEnabled,
            lastProgressUpdate: lastProgressUpdate,
            recurrenceRule: recurrenceRule,
            taskSource: taskSource,
            voiceSnapshotData: voiceSnapshot.flatMap { try? JSONEncoder().encode($0) }
        )
    }
}

struct ChecklistItem: Codable, Identifiable {
    var id: UUID
    var name: String
    var isChecked: Bool
    var sortOrder: Int
    var quantity: Int = 1
    var isStarred: Bool = false
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
