import Foundation
import UserNotifications
import UIKit
import Supabase
import SwiftUI

@MainActor
class PushNotificationManager: NSObject, UNUserNotificationCenterDelegate, UIApplicationDelegate {
    static let shared = PushNotificationManager()
    
    private let supabase = SupabaseConfig.client
    var pendingTaskNavigation: UUID?
    /// When true, open Contacts/Invites (e.g. from invite push notification)
    var pendingInviteView = false
    
    /// Must be nonisolated so @UIApplicationDelegateAdaptor can instantiate
    /// this class without triggering a @MainActor dispatch assertion in Swift 6.
    nonisolated override init() {
        super.init()
    }
    
    /// Call once from a @MainActor context (e.g. .task) to wire up the
    /// notification-center delegate.
    func configure() {
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: - Push Registration
    
    /// Uses the async version of requestAuthorization to avoid passing a closure
    /// that Swift 6 would assume is @MainActor but UNUserNotificationCenter
    /// calls on a background thread (causes _dispatch_assert_queue_fail).
    func registerForPushNotifications() {
        _Concurrency.Task {
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } catch {
                print("Push notification authorization error: \(error)")
            }
        }
    }
    
    // MARK: - Device Token Handling
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        _Concurrency.Task {
            await saveDeviceToken(tokenString)
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }
    
    private func saveDeviceToken(_ token: String) async {
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id.uuidString
            
            // Upsert device token
            struct DeviceTokenInsert: Encodable {
                let userId: String
                let token: String
                let platform: String
                
                enum CodingKeys: String, CodingKey {
                    case userId = "user_id"
                    case token
                    case platform
                }
            }
            
            let insert = DeviceTokenInsert(userId: userId, token: token, platform: "ios")
            
            try await supabase
                .from("device_tokens")
                .upsert(insert, onConflict: "user_id,token")
                .execute()
        } catch {
            print("Error saving device token: \(error)")
        }
    }
    
    func deleteDeviceToken() async {
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id.uuidString
            
            try await supabase
                .from("device_tokens")
                .delete()
                .eq("user_id", value: userId)
                .execute()
        } catch {
            print("Error deleting device token: \(error)")
        }
    }
    
    // MARK: - Notification Handling
    
    // Handle notification when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner and play sound even when app is open
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        // Route by type: task_share_invite -> Contacts/Invites; task_id -> open task
        if let type = userInfo["type"] as? String, type == "task_share_invite" {
            _Concurrency.Task { @MainActor in
                PushNotificationManager.shared.pendingInviteView = true
                NotificationCenter.default.post(name: NSNotification.Name("PendingInviteView"), object: nil)
            }
        } else if let taskIdString = userInfo["task_id"] as? String,
           let taskId = UUID(uuidString: taskIdString) {
            _Concurrency.Task { @MainActor in
                PushNotificationManager.shared.pendingTaskNavigation = taskId
                NotificationCenter.default.post(name: NSNotification.Name("PendingTaskNavigation"), object: taskId)
            }
        }
        
        completionHandler()
    }
}
