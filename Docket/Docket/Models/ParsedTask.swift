import Foundation

struct ParsedTask: Codable, Identifiable {
    let id: UUID
    var title: String
    var dueDate: Date?
    var hasTime: Bool // true if the AI returned a datetime (HH:mm), false if date-only
    var priority: String // "low", "medium", "high"
    var category: String?
    var notes: String?
    var shareWith: String? // email or display name
    var suggestion: String?
    var checklistItems: [String]? // AI-suggested item names (ad-hoc grocery list)
    var useTemplate: String? // store name whose template to load (template-based grocery list)
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case dueDate
        case priority
        case category
        case notes
        case shareWith
        case suggestion
        case checklistItems
        case useTemplate
    }
}

struct ConversationMessage: Codable {
    let role: String // "user" or "assistant"
    let content: String
}

struct ParseResponse: Codable {
    let type: String // "question", "complete", "update", or "delete"
    let text: String? // follow-up question (when type == "question")
    let tasks: [ParsedTask]? // extracted tasks (when type == "complete")
    let taskId: String? // existing task ID (when type == "update" or "delete")
    let changes: TaskChanges? // fields to change (when type == "update")
    let summary: String? // TTS readback (when type == "complete", "update", or "delete")
}

/// Context about an existing task, sent to Edge Function for awareness
struct TaskContext: Codable {
    let id: String // UUID as string
    let title: String
    let dueDate: String? // ISO 8601: "yyyy-MM-dd" or "yyyy-MM-ddTHH:mm"
    let priority: String // "low", "medium", "high"
    let category: String?
    let isCompleted: Bool
}

/// Context about a grocery store template, sent to Edge Function for awareness
struct GroceryStoreContext: Codable {
    let name: String
    let itemCount: Int
}

/// Changes to apply to an existing task, returned from Edge Function
struct TaskChanges: Codable {
    var title: String?
    var dueDate: String? // ISO 8601: "yyyy-MM-dd" or "yyyy-MM-ddTHH:mm"
    var priority: String? // "low", "medium", "high"
    var category: String?
    var notes: String?
    var isCompleted: Bool?
    var isPinned: Bool? // Pin/unpin task
    var addChecklistItems: [String]? // Add items to existing checklist
    var removeChecklistItems: [String]? // Remove items from checklist (by name)
    var starChecklistItems: [String]? // Star items (mark as important)
    var unstarChecklistItems: [String]? // Unstar items
    var checkChecklistItems: [String]? // Check items (mark as done)
    var uncheckChecklistItems: [String]? // Uncheck items
    
    /// Decodes dueDate string to Date + hasTime flag
    func decodeDueDate() -> (date: Date?, hasTime: Bool) {
        guard let dateString = dueDate else {
            return (nil, false)
        }
        
        if dateString.contains("T") {
            // DateTime format: "2026-02-09T09:00"
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
            formatter.timeZone = TimeZone.current
            let date = formatter.date(from: dateString)
            return (date, date != nil)
        } else {
            // Date-only format: "2026-02-09"
            // Parse as local date (not UTC) to avoid timezone shifts
            let components = dateString.split(separator: "-")
            if components.count == 3,
               let year = Int(components[0]),
               let month = Int(components[1]),
               let day = Int(components[2]) {
                var calendar = Calendar.current
                calendar.timeZone = TimeZone.current
                let date = calendar.date(from: DateComponents(year: year, month: month, day: day))
                return (date, false)
            } else {
                // Fallback to ISO8601DateFormatter if parsing fails
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
                formatter.timeZone = TimeZone.current // Use local timezone, not UTC
                let date = formatter.date(from: dateString)
                return (date, false)
            }
        }
    }
}

extension ParsedTask {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        
        // Decode dueDate — supports two formats:
        //   "yyyy-MM-dd"          → date-only (hasTime = false)
        //   "yyyy-MM-ddTHH:mm"    → date + time (hasTime = true)
        if let dateString = try container.decodeIfPresent(String.self, forKey: .dueDate) {
            if dateString.contains("T") {
                // DateTime format: "2026-02-09T09:00"
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
                formatter.timeZone = TimeZone.current // Use local timezone since user said "9am"
                dueDate = formatter.date(from: dateString)
                hasTime = dueDate != nil
            } else {
                // Date-only format: "2026-02-09"
                // Parse as local date (not UTC) to avoid timezone shifts
                // e.g., "2026-02-09" should be Thursday in user's timezone, not UTC midnight
                let components = dateString.split(separator: "-")
                if components.count == 3,
                   let year = Int(components[0]),
                   let month = Int(components[1]),
                   let day = Int(components[2]) {
                    var calendar = Calendar.current
                    calendar.timeZone = TimeZone.current
                    dueDate = calendar.date(from: DateComponents(year: year, month: month, day: day))
                } else {
                    // Fallback to ISO8601DateFormatter if parsing fails
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
                    formatter.timeZone = TimeZone.current // Use local timezone, not UTC
                    dueDate = formatter.date(from: dateString)
                }
                hasTime = false
            }
        } else {
            dueDate = nil
            hasTime = false
        }
        
        priority = try container.decode(String.self, forKey: .priority)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        shareWith = try container.decodeIfPresent(String.self, forKey: .shareWith)
        suggestion = try container.decodeIfPresent(String.self, forKey: .suggestion)
        checklistItems = try container.decodeIfPresent([String].self, forKey: .checklistItems)
        useTemplate = try container.decodeIfPresent(String.self, forKey: .useTemplate)
    }
}
