import SwiftUI
import Supabase
import _Concurrency

struct NotificationsListView: View {
    @Environment(SyncEngine.self) private var syncEngine
    @State private var notifications: [NotificationRow] = []
    @State private var isLoading = true
    
    var body: some View {
        List {
            if isLoading && notifications.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else if notifications.isEmpty {
                ContentUnavailableView {
                    Label("No Notifications", systemImage: "bell.slash")
                } description: {
                    Text("You're all caught up.")
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(notifications) { notification in
                    notificationRow(notification)
                }
            }
        }
        .navigationTitle("Notifications")
        .refreshable {
            await loadNotifications()
        }
        .onAppear {
            _Concurrency.Task {
                await loadNotifications()
            }
        }
        .onDisappear {
            NotificationCenter.default.post(name: NSNotification.Name("NotificationsViewDismissed"), object: nil)
        }
    }
    
    private func notificationRow(_ notification: NotificationRow) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconForType(notification.type))
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 36, alignment: .center)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(titleForNotification(notification))
                    .font(.body)
                    .fontWeight(notification.readAt == nil ? .semibold : .regular)
                if let sub = subtitleForNotification(notification) {
                    Text(sub)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if notification.readAt == nil {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            handleNotificationTap(notification)
        }
    }
    
    private func iconForType(_ type: String) -> String {
        switch type {
        case "task_share_invite": return "checklist.badge.plus"
        default: return "bell"
        }
    }
    
    private func titleForNotification(_ notification: NotificationRow) -> String {
        switch notification.type {
        case "task_share_invite": return "Task share invite"
        default: return "Notification"
        }
    }
    
    private func subtitleForNotification(_ notification: NotificationRow) -> String? {
        notification.payload.taskId != nil ? "Tap to view in Contacts" : nil
    }
    
    private func handleNotificationTap(_ notification: NotificationRow) {
        if notification.type == "task_share_invite" {
            // Open Contacts to accept/decline
            NotificationCenter.default.post(name: NSNotification.Name("PendingInviteView"), object: nil)
        }
        markAsRead(notification.id)
    }
    
    private func markAsRead(_ id: UUID) {
        _Concurrency.Task {
            do {
                struct ReadAtUpdate: Encodable {
                    let readAt: Date
                    enum CodingKeys: String, CodingKey { case readAt = "read_at" }
                }
                try await SupabaseConfig.client
                    .from("notifications")
                    .update(ReadAtUpdate(readAt: Date()))
                    .eq("id", value: id.uuidString)
                    .execute()
                await loadNotifications()
            } catch {
                print("Mark read error: \(error)")
            }
        }
    }
    
    private func loadNotifications() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let session = try await SupabaseConfig.client.auth.session
            let userId = session.user.id.uuidString
            
            let response: [NotificationRow] = try await SupabaseConfig.client
                .from("notifications")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value
            
            notifications = response
        } catch {
            notifications = []
        }
    }
}

struct NotificationRow: Codable, Identifiable {
    let id: UUID
    let type: String
    let payload: NotificationPayload
    let readAt: Date?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case payload
        case readAt = "read_at"
        case createdAt = "created_at"
    }
}

struct NotificationPayload: Codable {
    let taskShareId: String?
    let taskId: String?
    let ownerId: String?
    let sharedWithEmail: String?
    
    enum CodingKeys: String, CodingKey {
        case taskShareId = "task_share_id"
        case taskId = "task_id"
        case ownerId = "owner_id"
        case sharedWithEmail = "shared_with_email"
    }
    
    subscript(key: String) -> String? {
        switch key {
        case "task_share_id": return taskShareId
        case "task_id": return taskId
        case "owner_id": return ownerId
        case "shared_with_email": return sharedWithEmail
        default: return nil
        }
    }
}

#Preview {
    NavigationStack {
        NotificationsListView()
    }
}
