import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    
    private let center = UNUserNotificationCenter.current()
    
    func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
    }
    
    func scheduleNotification(for task: Task) async {
        let identifier = notificationId(for: task.id)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        
        guard let dueDate = task.dueDate, !task.isCompleted else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Task Due"
        content.body = task.title
        content.sound = .default
        
        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: dueDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }
    
    func cancelNotification(taskId: UUID) async {
        let identifier = notificationId(for: taskId)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    func scheduleSharedTaskNotification(from sender: String, taskTitle: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Task Shared"
        content.body = "\(sender) shared \"\(taskTitle)\""
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "shared-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }
    
    private func notificationId(for taskId: UUID) -> String {
        "task-\(taskId.uuidString)"
    }
}
