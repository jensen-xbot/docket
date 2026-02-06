import Foundation

extension Date {
    // MARK: - Formatting
    
    var formattedDueDate: String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(self) {
            return "Today"
        } else if calendar.isDateInTomorrow(self) {
            return "Tomorrow"
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: self)
        }
    }
    
    var formattedRelative: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    var formattedShort: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    var formattedDateTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    // MARK: - Relative Date Logic
    
    func daysUntil() -> Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfDueDate = calendar.startOfDay(for: self)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfDueDate)
        return components.day ?? 0
    }
    
    func daysSince() -> Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfDueDate = calendar.startOfDay(for: self)
        let components = calendar.dateComponents([.day], from: startOfDueDate, to: startOfToday)
        return components.day ?? 0
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(self)
    }
    
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }
    
    var isPast: Bool {
        self < Date()
    }
    
    var isFuture: Bool {
        self > Date()
    }
    
    // MARK: - Date Creation Helpers
    
    static func daysFromNow(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
    }
    
    static var startOfToday: Date {
        Calendar.current.startOfDay(for: Date())
    }
    
    static var endOfToday: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfToday) ?? Date()
    }
}

// MARK: - Task Due Date Display

extension Task {
    var dueDateDisplay: String {
        guard let dueDate = dueDate else { return "No due date" }
        return dueDate.formattedDueDate
    }
    
    var dueDateDetailDisplay: String {
        guard let dueDate = dueDate else { return "" }
        
        if isOverdue {
            let days = dueDate.daysSince()
            return days == 1 ? "1 day overdue" : "\(days) days overdue"
        } else if isDueSoon {
            let days = dueDate.daysUntil()
            if days == 0 {
                return "Due today"
            } else if days == 1 {
                return "Due tomorrow"
            } else {
                return "Due in \(days) days"
            }
        } else {
            return dueDate.formattedRelative
        }
    }
}